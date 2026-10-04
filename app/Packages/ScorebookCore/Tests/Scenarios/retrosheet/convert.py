#!/usr/bin/env python3
"""Turns one Major League game from Retrosheet into a scorebook scenario file.

Credit, as Retrosheet asks of anyone using its data:

    The information used here was obtained free of charge from and is
    copyrighted by Retrosheet.  Interested parties may contact Retrosheet
    at "www.retrosheet.org".

What it reads
-------------
games/<GAME>.txt      One game's lines from a Retrosheet event file, copied as they are:
                      "id", "info", "start", "sub", "play", "com" and "data" lines.
games/<GAME>-box.txt  The official box score for that game, typed in by hand from
                      Retrosheet's box score page (the format is explained at the top of
                      each box file).

What it writes
--------------
<name>.json           A scenario: the game's setup, every pitch and play as our events,
                      and the official box score as the expected stats.

How to run it (Python 3, nothing to install):

    python3 convert.py NYA201904210 2019-04-21-royals-at-yankees

How a Retrosheet "play" line becomes our events
-----------------------------------------------
A play line looks like this:

    play,8,0,mondr003,10,.BX,D9/L9M.3-H;2-H;1-3

inning 8, visitors batting (0), batter mondr003, count 1-0, pitches ".BX", and the
play "D9/L9M.3-H;2-H;1-3": a double to right on a line drive, the runners on third
and second score and the runner on first goes to third.

* Each pitch letter becomes a pitch event (B ball, C called strike, S swinging strike,
  F foul, T foul tip, L foul bunt, M missed bunt, H hit by pitch). The last "X" is the
  ball put in play, which becomes the ball-in-play event itself.
* Retrosheet repeats the whole pitch list each time the same batter appears again (after
  a stolen base, say), so only the new pitches are used.
* Steals, wild pitches and other moves between pitches become runner-action events.
* "sub" lines become substitution or pitching-change events.
* At the end the converter adds the end-of-game event.

The converter keeps track of who is on each base, so it can name every runner, and counts
balls and strikes so it can stop with a clear message if the pitches and the play disagree.
Anything it does not understand also stops it with a message, rather than guessing.
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

CREDIT = ('The information used here was obtained free of charge from and is copyrighted by '
          'Retrosheet. Interested parties may contact Retrosheet at "www.retrosheet.org".')

# Retrosheet's team codes for the teams in the games converted so far.
TEAM_NAMES = {
    'HOU': 'Houston Astros', 'KCA': 'Kansas City Royals', 'NYA': 'New York Yankees',
    'NYN': 'New York Mets', 'SDN': 'San Diego Padres',
}

# Pitch letters that are real pitches, and what each one is in our vocabulary.
PITCHES = {
    'B': 'ball', 'P': 'ball',            # P is a pitchout: a ball
    'C': 'calledStrike', 'K': 'calledStrike',  # K is a strike of unknown kind
    'S': 'swingingStrike', 'M': 'swingingStrike', 'Q': 'swingingStrike',  # M missed bunt, Q swing at a pitchout
    'F': 'foul', 'R': 'foul',            # R is a foul on a pitchout
    'T': 'foulTip', 'L': 'foulBunt', 'O': 'foulBunt',
    'H': 'hitByPitch',
}
# Marks in the pitch list that are not pitches: pickoff throws (1, 2, 3, +), a ball the
# catcher blocked (*), a runner going (>), and the dot that marks where a play happened.
NOT_PITCHES = set('123+*>.N')

BASE_NAMES = {'1': 'first', '2': 'second', '3': 'third', 'H': 'scored', 'B': 'home'}
BASE_NUMBER = {'B': 0, '1': 1, '2': 2, '3': 3, 'H': 4}

# Runner moves between pitches, by the Retrosheet code that starts the play.
RUNNER_REASONS = {
    'SB': 'stolenBase', 'CS': 'caughtStealing', 'POCS': 'caughtStealing', 'PO': 'pickoff',
    'WP': 'wildPitch', 'PB': 'passedBall', 'BK': 'balk', 'DI': 'defensiveIndifference',
    'OA': 'other',
}


class ConvertError(Exception):
    """Something in the game the converter does not handle. The message says what."""


def split_outside_parentheses(text, separator):
    """Splits text at a separator, ignoring separators inside parentheses."""
    parts, depth, current = [], 0, ''
    for ch in text:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == separator and depth == 0:
            parts.append(current)
            current = ''
        else:
            current += ch
    parts.append(current)
    return parts


def parse_advance(text):
    """Reads one runner advance such as "2-H(E2/TH)(UR)" or "1X3(65)".

    Returns (from base, to base, is it an out, the notes in parentheses)."""
    m = re.match(r'^([B123])([-X])([123H])((?:\([^)]*\))*)$', text)
    if not m:
        raise ConvertError('cannot read the runner advance "%s"' % text)
    notes = re.findall(r'\(([^)]*)\)', m.group(4))
    is_out = m.group(2) == 'X'
    # An "out" with an error in its notes means the error let the runner stay safe.
    if is_out and any('E' in n for n in notes):
        is_out = False
    return m.group(1), m.group(3), is_out, notes


def fielders_in(notes):
    """The fielders named in parentheses, such as "(65)" -> [6, 5]."""
    for n in notes:
        if re.fullmatch(r'\d+', n):
            return [int(c) for c in n]
    return []


def errors_in(notes):
    """Errors named in parentheses, such as "(E2/TH)" -> [error on the catcher, throwing]."""
    found = []
    for n in notes:
        for m in re.finditer(r'E(\d)(/TH)?', n):
            found.append({'fielder': int(m.group(1)), 'type': 'throwing' if m.group(2) else 'fielding'})
    return found


def batted_ball(modifiers):
    """Ground ball, fly ball, line drive, pop-up or bunt, from the modifiers after the play."""
    for mod in modifiers:
        m = re.fullmatch(r'(BG|BP|BL|G|L|F|P)(\d+[A-Z]*[+-]?)?', mod)
        if m:
            return {'BG': 'bunt', 'BP': 'bunt', 'BL': 'bunt', 'G': 'groundBall',
                    'L': 'lineDrive', 'F': 'flyBall', 'P': 'popUp'}[m.group(1)]
    if 'GDP' in modifiers:
        return 'groundBall'
    return None


class Game:
    """Everything the converter keeps track of while reading one game."""

    def __init__(self, lines):
        self.info = {}
        self.roster = {0: [], 1: []}       # team (0 visitors, 1 home) -> players in order seen
        self.names = {}
        self.start_order = {0: {}, 1: {}}  # team -> batting spot (1-9) -> player
        self.start_defense = {0: {}, 1: {}}
        self.lines = []
        for raw in lines:
            raw = raw.strip()
            if not raw:
                continue
            fields = next_csv(raw)
            kind = fields[0]
            if kind == 'info':
                self.info[fields[1]] = fields[2] if len(fields) > 2 else ''
            elif kind == 'start':
                self.add_player(fields)
                pid, team, spot, pos = fields[1], int(fields[3]), int(fields[4]), int(fields[5])
                if spot > 0:
                    self.start_order[team][spot] = pid
                if 1 <= pos <= 9:
                    self.start_defense[team][pos] = pid
            elif kind == 'sub':
                self.add_player(fields)
                self.lines.append(fields)
            elif kind == 'play':
                self.lines.append(fields)
            elif kind in ('id', 'version', 'com', 'data'):
                pass  # nothing the scorebook needs
            else:
                raise ConvertError('cannot handle the "%s" line: %s' % (kind, raw))
        if self.info.get('usedh') not in ('true', 'false'):
            raise ConvertError('the game does not say whether a designated hitter was used')

    def add_player(self, fields):
        pid, name, team = fields[1], fields[2], int(fields[3])
        if pid not in self.names:
            self.names[pid] = name
            self.roster[team].append(pid)


def next_csv(line):
    """Splits a Retrosheet line at commas, keeping quoted names (with commas) together."""
    out, current, quoted = [], '', False
    for ch in line:
        if ch == '"':
            quoted = not quoted
        elif ch == ',' and not quoted:
            out.append(current)
            current = ''
        else:
            current += ch
    out.append(current)
    return out


class Converter:
    """Walks through the game's lines in order, writing our events."""

    def __init__(self, game):
        self.g = game
        self.events = []
        # Batting order: team -> list of 9 spots, each the player who holds it now.
        self.order = {t: [game.start_order[t][s] for s in range(1, 10)] for t in (0, 1)}
        self.pitcher = {t: game.start_defense[t][1] for t in (0, 1)}
        self.bases = {}          # '1', '2', '3' -> player on that base
        self.outs = 0
        self.inning, self.half = 1, 0   # half: 0 top (visitors bat), 1 bottom
        self.score = [0, 0]
        self.balls = self.strikes = 0
        self.seen_pitches = ''   # the pitch list already turned into events for this batter
        self.pending_subs = []   # sub lines waiting to be grouped into one substitution

    # ----- small helpers

    def add(self, kind, details):
        """Adds one event with the next id."""
        self.events.append({'id': 'e%d' % (len(self.events) + 1), kind: details})

    def side(self, team):
        return 'away' if team == 0 else 'home'

    def spot_of(self, team, player):
        for i, p in enumerate(self.order[team]):
            if p == player:
                return i
        return None

    # ----- substitutions

    def flush_subs(self):
        """Writes the waiting non-pitcher substitutions for one team as a single event."""
        if not self.pending_subs:
            return
        team = int(self.pending_subs[0][3])
        batting, defense = [], []
        for f in self.pending_subs:
            pid, spot, pos = f[1], int(f[4]), int(f[5])
            holder = self.order[team][spot - 1] if spot > 0 else None
            if spot > 0 and holder != pid:
                kind = {11: 'pinchHitter', 12: 'pinchRunner'}.get(pos, 'replacement')
                batting.append({'kind': kind, 'incoming': pid, 'replacing': holder})
                self.order[team][spot - 1] = pid
                if pos == 12:
                    for b, r in self.bases.items():
                        if r == holder:
                            self.bases[b] = pid
            if 2 <= pos <= 9:
                defense = [d for d in defense if d['position'] != pos and d['player'] != pid]
                defense.append({'position': pos, 'player': pid})
        details = {'team': self.side(team)}
        if batting:
            details['batting'] = batting
        if defense:
            details['defense'] = defense
        if batting or defense:
            self.add('substitution', details)
        self.pending_subs = []

    def sub(self, f):
        """One "sub" line: a new pitcher is a pitching change; anything else waits to be grouped."""
        pid, team, spot, pos = f[1], int(f[3]), int(f[4]), int(f[5])
        if self.pending_subs and int(self.pending_subs[0][3]) != team:
            self.flush_subs()
        if pos == 1:
            self.flush_subs()
            details = {'team': self.side(team), 'newPitcher': pid}
            if spot > 0 and self.order[team][spot - 1] != pid:
                details['takesBattingSpotOf'] = self.order[team][spot - 1]
                self.order[team][spot - 1] = pid
            self.pitcher[team] = pid
            self.add('pitchingChange', details)
        else:
            self.pending_subs.append(f)

    # ----- pitches

    def pitch_letters(self, sequence):
        """The pitches in a pitch list that have not been turned into events yet."""
        if sequence.startswith(self.seen_pitches):
            new = sequence[len(self.seen_pitches):]
        else:
            raise ConvertError('the pitch list "%s" does not continue "%s"' % (sequence, self.seen_pitches))
        self.seen_pitches = sequence
        letters = []
        for ch in new:
            if ch in NOT_PITCHES:
                continue
            if ch == 'X':
                letters.append('X')
            elif ch in PITCHES:
                letters.append(ch)
            else:
                raise ConvertError('cannot handle the pitch letter "%s"' % ch)
        return letters

    def add_pitches(self, letters, keep_last=False):
        """Writes pitch events and keeps the count. With keep_last, the last pitch is left
        for the caller (the strike three, ball four or hit by pitch that ends the batter)."""
        todo = letters[:-1] if keep_last else letters
        for ch in todo:
            if ch == 'X':
                raise ConvertError('a ball in play in the middle of a pitch list')
            self.count_pitch(PITCHES[ch], ends_batter=False)
            self.add('pitch', {'result': PITCHES[ch]})

    def count_pitch(self, result, ends_batter):
        """Keeps balls and strikes, and stops if a pitch would end the batter too early."""
        if result == 'ball':
            self.balls += 1
            if self.balls == 4 and not ends_batter:
                raise ConvertError('ball four in the middle of a batter, inning %d' % self.inning)
        elif result == 'hitByPitch':
            pass
        elif result == 'foul' and self.strikes == 2:
            pass
        else:
            self.strikes += 1
            if self.strikes == 3 and not ends_batter:
                raise ConvertError('strike three in the middle of a batter, inning %d' % self.inning)

    # ----- runners

    def move(self, frm, to, out, notes, batter, reason=None, out_by=None):
        """One runner move in our vocabulary, read from Retrosheet base codes."""
        runner = batter if frm == 'B' else self.bases.get(frm)
        if runner is None:
            raise ConvertError('nobody on base %s in inning %d' % (frm, self.inning))
        m = {'runner': runner, 'from': BASE_NAMES[frm], 'to': 'out' if out else BASE_NAMES[to]}
        if reason:
            m['reason'] = reason
        fielders = out_by if out_by is not None else fielders_in(notes)
        if out:
            if not fielders:
                raise ConvertError('an out with no fielders named, inning %d' % self.inning)
            m['outBy'] = fielders
            m['outAt'] = {'1': 'first', '2': 'second', '3': 'third', 'H': 'home'}[to]
        if not out and any('E' in n for n in notes):
            m['advancedOnError'] = True
        return m

    def apply_moves(self, moves):
        """Moves the runners on our own copy of the bases, and counts outs and runs."""
        after = {b: r for b, r in self.bases.items()}
        for m in moves:
            if m['from'] != 'home':
                code = {'first': '1', 'second': '2', 'third': '3'}[m['from']]
                if after.get(code) == m['runner']:
                    del after[code]
        for m in moves:
            if m['to'] == 'out':
                self.outs += 1
            elif m['to'] == 'scored':
                self.score[self.half] += 1
            else:
                code = {'first': '1', 'second': '2', 'third': '3'}[m['to']]
                if code in after:
                    raise ConvertError('two runners on base %s in inning %d' % (code, self.inning))
                after[code] = m['runner']
        self.bases = after

    def forced_moves(self, batter):
        """Walk or hit by pitch: the batter to first and every forced runner up one base."""
        moves = [{'runner': batter, 'from': 'home', 'to': 'first'}]
        if '1' in self.bases:
            moves.append({'runner': self.bases['1'], 'from': 'first', 'to': 'second'})
            if '2' in self.bases:
                moves.append({'runner': self.bases['2'], 'from': 'second', 'to': 'third'})
                if '3' in self.bases:
                    moves.append({'runner': self.bases['3'], 'from': 'third', 'to': 'scored'})
        return moves

    # ----- the plays

    def play(self, f):
        inning, half, batter, sequence, text = int(f[1]), int(f[2]), f[3], f[5], f[6]
        if (inning, half) != (self.inning, self.half):
            raise ConvertError('expected inning %d half %d, found %d %d' % (self.inning, self.half, inning, half))
        if text == 'NP':
            return  # "no play": a substitution follows, possibly one of several made together
        self.flush_subs()
        if self.order[half][self.batter_index(half)] != batter:
            raise ConvertError('expected %s to bat, found %s' % (self.order[half][self.batter_index(half)], batter))
        letters = self.pitch_letters(sequence)

        main, _, adv_text = text.partition('.')
        advances = [parse_advance(a) for a in adv_text.split(';')] if adv_text else []
        parts = split_outside_parentheses(main, '/')
        basic, modifiers = parts[0], parts[1:]

        code = re.match(r'[A-Z]*', basic).group(0)
        if code in ('SB', 'CS', 'POCS', 'PO', 'WP', 'PB', 'BK', 'DI', 'OA'):
            self.add_pitches(letters)
            self.runner_event(basic, advances, batter)
            return
        if basic.startswith('K'):
            self.strikeout(basic, modifiers, advances, letters, batter)
        elif basic in ('W', 'IW', 'I', 'HP') or basic.startswith(('W+', 'IW+', 'HP+')):
            self.free_base(basic, advances, letters, batter)
        else:
            self.ball_in_play(basic, modifiers, advances, letters, batter)
        self.end_batter(half)

    def batter_index(self, team):
        return self.next_spot[team]

    def end_batter(self, team):
        self.next_spot[team] = (self.next_spot[team] + 1) % 9
        self.balls = self.strikes = 0
        self.seen_pitches = ''
        self.check_third_out()

    def check_third_out(self):
        if self.outs >= 3:
            self.outs = 0
            self.bases = {}
            self.balls = self.strikes = 0
            self.seen_pitches = ''
            if self.half == 0:
                self.half = 1
            else:
                self.half, self.inning = 0, self.inning + 1

    def runner_event(self, basic, advances, batter, after_strikeout=False):
        """A steal, caught stealing, pickoff, wild pitch, passed ball, balk or the like.
        `after_strikeout` is true for a runner play on the same pitch as strike three: a runner
        put out then makes it one double play with the strikeout."""
        moves, errors = [], []
        listed = {a[0] for a in advances}
        for piece in basic.split(';'):
            m = re.fullmatch(r'(POCS|SB|CS|PO|WP|PB|BK|DI|OA)([123H]?)((?:\([^)]*\))*)', piece)
            if not m:
                raise ConvertError('cannot read the runner play "%s"' % piece)
            kind, base, paren = m.group(1), m.group(2), m.group(3)
            notes = re.findall(r'\(([^)]*)\)', paren)
            reason = RUNNER_REASONS[kind]
            errors += errors_in(notes)
            if kind == 'SB':
                frm = {'2': '1', '3': '2', 'H': '3'}[base]
                if frm not in listed:
                    moves.append(self.move(frm, base, False, notes, batter, reason))
            elif kind in ('CS', 'POCS'):
                frm = {'2': '1', '3': '2', 'H': '3'}[base]
                if errors_in(notes):
                    raise ConvertError('a caught stealing undone by an error is not handled')
                moves.append(self.move(frm, base, True, notes, batter, reason))
            elif kind == 'PO':
                if errors_in(notes):
                    continue  # a pickoff throw that got away: the advance says where the runner went
                moves.append(self.move(base, base, True, notes, batter, reason))
        main_reason = RUNNER_REASONS[re.match(r'[A-Z]+', basic).group(0)]
        for frm, to, out, notes in advances:
            errors += errors_in(notes)
            moves.append(self.move(frm, to, out, notes, batter, main_reason))
        if not moves:
            raise ConvertError('a runner play with nobody moving: %s' % basic)
        details = {'moves': moves}
        if errors:
            details['errors'] = errors
        if after_strikeout and any(m['to'] == 'out' for m in moves):
            details['completesStrikeoutDoublePlay'] = True
        self.add('runnerAction', details)
        self.apply_moves(moves)
        self.check_third_out()

    def strikeout(self, basic, modifiers, advances, letters, batter):
        """Strike three, with anything that happened on the same pitch."""
        if not letters or letters[-1] not in PITCHES:
            raise ConvertError('a strikeout with no strike-three pitch')
        self.add_pitches(letters, keep_last=True)
        last = PITCHES[letters[-1]]
        self.count_pitch(last, ends_batter=True)
        if self.strikes != 3:
            raise ConvertError('a strikeout at %d-%d in inning %d' % (self.balls, self.strikes, self.inning))
        main, _, extra = basic.partition('+')
        batter_safe = [a for a in advances if a[0] == 'B' and not a[2]]
        thrown_out = re.fullmatch(r'K(\d+)', main)
        if batter_safe or thrown_out:
            raise ConvertError('dropped third strikes are not handled yet')
        self.add('pitch', {'result': last})
        self.outs += 1
        if extra:
            # Strike three and a runner play on the same pitch (K+SB2, K+PO1(23)/DP): the
            # strikeout is the pitch, and the runner play follows as its own event, marked as
            # completing a double play with the strikeout when it puts a runner out.
            if self.outs >= 3:
                raise ConvertError('a runner play after the third out')
            self.runner_event(extra, [a for a in advances if a[0] != 'B'], batter, after_strikeout=True)
        elif advances:
            raise ConvertError('runners moving on a plain strikeout are not handled')

    def free_base(self, basic, advances, letters, batter):
        """A walk, intentional walk or hit by pitch: the batter goes to first."""
        main = basic.split('+')[0]
        if main in ('IW', 'I'):
            if [ch for ch in letters if ch not in 'I']:
                raise ConvertError('an intentional walk with pitches thrown')
            self.add('intentionalWalk', {})
        else:
            if not letters:
                raise ConvertError('a walk or hit by pitch with no pitches listed')
            self.add_pitches(letters, keep_last=True)
            last = PITCHES[letters[-1]]
            self.count_pitch(last, ends_batter=True)
            if main == 'W' and self.balls != 4:
                raise ConvertError('a walk at %d-%d' % (self.balls, self.strikes))
            if main == 'HP' and last != 'hitByPitch':
                raise ConvertError('a hit by pitch whose last pitch is not "H"')
            self.add('pitch', {'result': last})
        forced = self.forced_moves(batter)
        # Every advance Retrosheet lists must be one of the forced moves; anything more
        # (a runner taking an extra base on a wild pitch, say) is not handled yet.
        for frm, to, out, notes in advances:
            match = [m for m in forced if m['from'] == BASE_NAMES[frm]]
            if out or not match or match[0]['to'] != BASE_NAMES[to]:
                raise ConvertError('an advance past the forced base on "%s" is not handled yet' % basic)
        if '+' in basic:
            raise ConvertError('a walk or hit by pitch together with another play is not handled yet')
        self.apply_moves(forced)

    def ball_in_play(self, basic, modifiers, advances, letters, batter):
        """A hit, an out, an error, a fielder's choice: one ball in play."""
        if letters and letters[-1] == 'X':
            self.add_pitches(letters[:-1])
        elif letters:
            raise ConvertError('a ball in play whose last pitch is not "X": %s' % basic)
        play = {'runners': []}
        moves = play['runners']
        errors = []
        listed = {a[0] for a in advances}
        batter_out = False

        hit = re.fullmatch(r'(S|D|T|HR|H|DGR)(\d*)', basic)
        error = re.fullmatch(r'E(\d)', basic)
        choice = re.fullmatch(r'FC(\d?)', basic)
        outs = re.fullmatch(r'(\d+(?:\([B123]\))?)+', basic)
        if hit:
            kind = {'S': 'single', 'D': 'double', 'DGR': 'double', 'T': 'triple', 'HR': 'homeRun', 'H': 'homeRun'}[hit.group(1)]
            play['batterResult'] = kind
            if hit.group(2):
                play['hitLocation'] = int(hit.group(2)[0])
            default_batter = {'single': '1', 'double': '2', 'triple': '3', 'homeRun': 'H'}[kind]
        elif error:
            play['batterResult'] = 'reachedOnError'
            play['fielders'] = [int(error.group(1))]
            errors.append({'fielder': int(error.group(1)), 'type': 'throwing' if 'TH' in modifiers else 'fielding'})
            default_batter = '1'
        elif choice:
            play['batterResult'] = 'fieldersChoice'
            if choice.group(1):
                play['fielders'] = [int(choice.group(1))]
            default_batter = '1'
        elif outs:
            # Groups of fielders, each ending at a runner put out: "64(1)3" is a force at
            # second (6 to 4) and then the batter out at first (4 to 3).
            groups = re.findall(r'(\d+)(?:\(([B123])\))?', basic)
            fielders, previous_last = [], None
            for digits, base in groups:
                chain = ([previous_last] if previous_last is not None else []) + [int(c) for c in digits]
                previous_last = chain[-1]
                for c in [int(c) for c in digits]:
                    if not fielders or fielders[-1] != c:
                        fielders.append(c)
                runner_base = base or 'B'
                if runner_base == 'B':
                    batter_out = True
                    moves.append(self.move('B', '1', True, [], batter, out_by=chain))
                    moves[-1].pop('outAt')
                    if len(chain) > 1:
                        moves[-1]['outAt'] = 'first'
                else:
                    to = {'1': '2', '2': '3', '3': 'H'}[runner_base]
                    moves.append(self.move(runner_base, to, True, [], batter, out_by=chain))
            play['fielders'] = fielders
            if 'SF' in modifiers:
                play['batterResult'] = 'sacrificeFly'
            elif 'SH' in modifiers:
                play['batterResult'] = 'sacrificeBunt'
            elif batter_out:
                play['batterResult'] = 'out'
            else:
                play['batterResult'] = 'fieldersChoice'   # a force out: the batter is safe at first
            default_batter = None if batter_out else '1'
        else:
            raise ConvertError('cannot read the play "%s"' % basic)

        # Runners listed after the dot.
        for frm, to, out, notes in advances:
            errors += errors_in(notes)
            if frm == 'B' and batter_out:
                raise ConvertError('a batter both out and advancing: %s' % basic)
            moves.append(self.move(frm, to, out, notes, batter))
        # The batter's own move when it was not listed.
        if 'B' not in listed and default_batter:
            moves.append({'runner': batter, 'from': 'home', 'to': BASE_NAMES[default_batter]})
            if error:
                moves[-1]['advancedOnError'] = True

        bb = batted_ball(modifiers)
        if bb:
            play['battedBall'] = bb
        if errors:
            play['errors'] = errors
        if any(m in modifiers for m in ('DP', 'GDP', 'LDP', 'FDP', 'BGDP', 'BPDP')):
            play['multiOut'] = 'doublePlay'
        if any(m in modifiers for m in ('TP', 'GTP', 'LTP', 'FTP')):
            play['multiOut'] = 'triplePlay'
        play['rbi'] = self.runs_batted_in(play, advances, modifiers)
        # Our order of keys, for easier reading.
        ordered = {k: play[k] for k in ('batterResult', 'battedBall', 'fielders', 'hitLocation', 'runners', 'errors', 'multiOut', 'rbi') if k in play}
        self.add('ballInPlay', ordered)
        self.apply_moves(moves)

    def runs_batted_in(self, play, advances, modifiers):
        """Runs batted in, the way Retrosheet marks them: every run that scores counts unless
        marked (NR) or (NORBI), except on an error or a ground-ball double play, where only a
        run marked (RBI) counts. A home run counts the batter's own run."""
        no_default = play['batterResult'] == 'reachedOnError' or 'GDP' in modifiers
        rbi = 0
        for frm, to, out, notes in advances:
            if to != 'H' or out:
                continue
            if 'RBI' in notes:
                rbi += 1
            elif not no_default and 'NR' not in notes and 'NORBI' not in notes:
                rbi += 1
        if play['batterResult'] == 'homeRun' and not any(a[0] == 'B' for a in advances):
            rbi += 1
        return rbi

    def run(self):
        self.next_spot = {0: 0, 1: 0}
        for f in self.g.lines:
            if f[0] == 'sub':
                self.sub(f)
            else:
                self.play(f)
        self.flush_subs()
        final = {'away': self.score[0], 'home': self.score[1]}
        self.add('endOfGame', {'reason': 'regulation', 'finalScore': final})
        return final


# ----- the official box score

def read_box(path):
    """Reads a hand-typed box score file (see the comments at the top of each one)."""
    box = {'line': {}, 'team': {}, 'bat': {}, 'pit': {}, 'fld': {}}
    for raw in open(path, encoding='utf-8'):
        raw = raw.strip()
        if not raw or raw.startswith('#'):
            continue
        fields = raw.split(',')
        kind, who = fields[0], fields[1]
        if kind == 'line':
            box['line'][who] = [None if x == 'x' else int(x) for x in fields[2:]]
        else:
            values = {}
            for item in fields[2:]:
                k, v = item.split('=')
                values[k] = v
            box[kind][who] = values
    return box


def outs_from_innings(ip):
    """Innings pitched as printed ("6.1") to outs (19)."""
    whole, _, thirds = ip.partition('.')
    return int(whole) * 3 + (int(thirds) if thirds else 0)


def expected_stats(box, game, converter):
    """The official box score in our expected-stats format. Batting numbers are given only
    for players who held a batting spot, and fielding only for players who took a position,
    since those are the players our box score has lines for."""
    batted = set()
    fielded = set()
    for t in (0, 1):
        batted.update(game.start_order[t].values())
        fielded.update(game.start_defense[t].values())
    for f in game.lines:
        if f[0] == 'sub':
            if int(f[4]) > 0:
                batted.add(f[1])
            if 1 <= int(f[5]) <= 9:
                fielded.add(f[1])
    n = lambda d, k: int(d.get(k, 0))
    batting = []
    for pid, b in box['bat'].items():
        if pid not in batted:
            continue
        pa = n(b, 'AB') + n(b, 'BB') + n(b, 'HBP') + n(b, 'SH') + n(b, 'SF')
        batting.append({'player': pid, 'plateAppearances': pa, 'atBats': n(b, 'AB'), 'runs': n(b, 'R'),
                        'hits': n(b, 'H'), 'doubles': n(b, '2B'), 'triples': n(b, '3B'), 'homeRuns': n(b, 'HR'),
                        'runsBattedIn': n(b, 'RBI'), 'walks': n(b, 'BB'), 'strikeouts': n(b, 'SO'),
                        'hitByPitch': n(b, 'HBP'), 'sacrificeFlies': n(b, 'SF'), 'sacrificeBunts': n(b, 'SH'),
                        'stolenBases': n(b, 'SB'), 'caughtStealing': n(b, 'CS')})
    pitching = []
    for pid, p in box['pit'].items():
        pitching.append({'pitcher': pid, 'outsRecorded': outs_from_innings(p['IP']), 'battersFaced': n(p, 'BFP'),
                         'hits': n(p, 'H'), 'runs': n(p, 'R'), 'walks': n(p, 'BB'), 'strikeouts': n(p, 'SO'),
                         'homeRuns': n(p, 'HR'), 'hitBatters': n(p, 'HBP')})
    fielding = []
    for pid, d in box['fld'].items():
        if pid in fielded:
            fielding.append({'player': pid, 'putouts': n(d, 'PO'), 'assists': n(d, 'A'), 'errors': n(d, 'E')})
    teams = []
    for side in ('away', 'home'):
        t = box['team'][side]
        teams.append({'team': side, 'runs': n(t, 'R'), 'hits': n(t, 'H'), 'errors': n(t, 'E'),
                      'leftOnBase': n(t, 'LOB'), 'lineScore': box['line'][side], 'doublePlays': n(t, 'DP')})
    return batting, pitching, fielding, teams


# ----- putting it together

def build_scenario(game_id, description_extra=''):
    lines = open(os.path.join(HERE, 'games', game_id + '.txt'), encoding='utf-8').read().splitlines()
    game = Game(lines)
    conv = Converter(game)
    final = conv.run()
    box = read_box(os.path.join(HERE, 'games', game_id + '-box.txt'))
    batting, pitching, fielding, teams = expected_stats(box, game, conv)
    if (final['away'], final['home']) != (int(box['team']['away']['R']), int(box['team']['home']['R'])):
        raise ConvertError('the converted score %s does not match the box score' % final)

    info = game.info
    away, home = info['visteam'], info['hometeam']
    y, mo, d = info['date'].split('/')
    hour, minute = re.match(r'(\d+):(\d+)', info.get('starttime', '1:00PM')).groups()
    hour = int(hour) % 12 + (12 if info.get('starttime', '').endswith('PM') else 0)

    def team(t, code):
        order = [game.start_order[t][s] for s in range(1, 10)]
        defense = [{'position': pos, 'player': pid} for pos, pid in sorted(game.start_defense[t].items())]
        roster = [{'id': pid, 'name': game.names[pid]} for pid in game.roster[t]]
        return {'teamID': code, 'name': TEAM_NAMES.get(code, code), 'isOurs': False, 'roster': roster,
                'battingOrder': order, 'defense': defense}

    setup = {
        # Retrosheet gives the local start time; it is written here as if it were UTC.
        'scheduledStart': '%s-%s-%sT%02d:%s:00Z' % (y, mo, d, hour, minute),
        'away': team(0, away),
        'home': team(1, home),
        # Major League rules: nine innings, no time limit, no run rule.
        'rules': {'scheduledInnings': 9, 'timeLimitMinutes': None, 'runRuleMargin': None},
    }
    words = '%s at %s, %s' % (TEAM_NAMES.get(away, away), TEAM_NAMES.get(home, home), '%s-%s-%s' % (y, mo, d))
    scenario = {
        'description': 'A complete Major League game from Retrosheet (game %s): %s, final %s %d, %s %d. '
                       'Every pitch and play, converted by retrosheet/convert.py; the expected stats are the '
                       'official box score.%s' % (game_id, words, TEAM_NAMES.get(away, away), final['away'],
                                                   TEAM_NAMES.get(home, home), final['home'], description_extra),
        'source': 'Retrosheet event file for game %s, with the box score at '
                  'https://www.retrosheet.org/boxesetc/%s/B%s%s%s.htm. %s' % (game_id, y, mo + d, game_id[-1], home + y, CREDIT),
        'setup': setup,
        'events': conv.events,
        'expected': {
            'situation': {'score': final, 'isFinal': True},
            'batting': batting,
            'pitching': pitching,
            'fielding': fielding,
            'teams': teams,
        },
    }
    return scenario


def main():
    if len(sys.argv) < 3:
        print('usage: python3 convert.py GAME_ID OUTPUT_NAME ["extra description"]')
        sys.exit(1)
    game_id, out_name = sys.argv[1], sys.argv[2]
    extra = (' ' + sys.argv[3]) if len(sys.argv) > 3 else ''
    try:
        scenario = build_scenario(game_id, extra)
    except ConvertError as problem:
        print('Could not convert %s: %s' % (game_id, problem))
        sys.exit(1)
    path = os.path.join(HERE, out_name + '.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(scenario, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print('Wrote %s: %d events' % (path, len(scenario['events'])))


if __name__ == '__main__':
    main()
