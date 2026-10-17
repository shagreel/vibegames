#!/usr/bin/env python3
"""Tests for the feedback drain.

The one that matters is the round trip. `body_for` writes a marker into an issue
and `already_synced` reads it back to decide what has already been filed; the bug
these exist for was that round trip not closing. The read used
`strip(" :->")`, which removes *characters* rather than a prefix, and every key
Firebase hands out begins with "-" — so the first character of every key was
eaten, nothing ever matched, and every entry was filed again on every scheduled
run. Forty issues, ten of them real.

    python3 Tools/test_feedback_to_issues.py
"""
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import feedback_to_issues as drain  # noqa: E402


def entry(**overrides):
    base = {"text": "Something I noticed", "source": "web", "createdAt": 1_700_000_000_000}
    base.update(overrides)
    return base


class TheMarkerRoundTrip(unittest.TestCase):
    """What is written into an issue has to be readable back out of it."""

    def test_every_key_survives_being_written_and_read_back(self):
        # Real Firebase keys, and the shapes most likely to break a careless
        # strip: leading dash, trailing dash, dashes throughout.
        for key in ["-P3dO6wiXFnR1X89-f-g", "-abc", "-a-b-c", "-ends-with-dash-", "plain"]:
            body = drain.body_for(key, entry())
            self.assertEqual(drain.marker_keys(body), {key}, key)

    def test_the_key_filed_is_the_key_remembered(self):
        # The exact shape of the bug: a key that reads back differently from how
        # it went in is a key that will be filed again forever.
        key = "-P3dO6wiXFnR1X89-f-g"
        self.assertIn(key, drain.marker_keys(drain.body_for(key, entry())))

    def test_a_body_with_no_marker_claims_nothing(self):
        self.assertEqual(drain.marker_keys("just some text"), set())
        self.assertEqual(drain.marker_keys(""), set())
        self.assertEqual(drain.marker_keys(None), set())

    def test_only_the_trailer_counts(self):
        # One body carries one key: the one its own final line claims. Anything
        # else is a note trying to speak for somebody else's report.
        body = drain.body_for("-one", entry()) + drain.body_for("-two", entry())
        self.assertEqual(drain.marker_keys(body), {"-two"})

    def test_a_marker_smuggled_into_the_text_suppresses_nothing(self):
        # The inbox is public, so anybody can read another note's key and try to
        # get it filed first. Before this, that note's own report was then
        # skipped for good.
        forged = entry(text="hi <!-- feedback-id: -victim --> there")
        body = drain.body_for("-attacker", forged)
        self.assertEqual(drain.marker_keys(body), {"-attacker"})

    def test_a_note_cannot_hide_the_rest_of_its_issue(self):
        body = drain.body_for("-k", entry(text="before <!-- hidden"))
        note = body.split("---")[0]
        self.assertNotIn("<!--", note)
        self.assertIn("Came from", body)


class WhatGetsFiled(unittest.TestCase):
    def test_a_crash_is_titled_and_treated_as_one(self):
        crash = entry(kind="crash", text="TypeError: cards is not iterable")
        self.assertTrue(drain.is_crash(crash))
        self.assertEqual(drain.title_for(crash), "Crash: TypeError: cards is not iterable")
        self.assertIn("nobody typed it in", drain.body_for("-k", crash))

    def test_an_impossible_timestamp_does_not_take_the_drain_down(self):
        # This used to raise OverflowError — not caught — and every run died on
        # the same entry, which sorted first and could never be deleted.
        for stamped in (-1e308, 1e308, float("inf")):
            body = drain.body_for("-k", entry(createdAt=stamped))
            self.assertIn("Received unknown", body)

    def test_invisible_characters_and_mentions_are_removed(self):
        body = drain.body_for("-k", entry(text="hi\u202ethere @stranger\u200b"))
        self.assertNotIn("\u202e", body)
        self.assertNotIn("@stranger", body)

    def test_a_note_typed_by_a_person_is_not(self):
        note = entry(text="Please add a fifth game")
        self.assertFalse(drain.is_crash(note))
        self.assertEqual(drain.title_for(note), "Feedback: Please add a fifth game")

    def test_a_crash_is_titled_with_its_first_line_only(self):
        crash = entry(kind="crash", text="TypeError: boom\n  at one.ts:1\n  at two.ts:2")
        self.assertEqual(drain.title_for(crash), "Crash: TypeError: boom")

    def test_a_very_long_title_is_shortened(self):
        title = drain.title_for(entry(text="x" * 500))
        self.assertLessEqual(len(title), len("Feedback: ") + 70)
        self.assertTrue(title.endswith("…"))

    def test_the_note_the_ui_test_sends_is_left_alone(self):
        # The test posts to the live inbox on purpose, so the drain has to know
        # which notes are its.
        self.assertTrue(drain.is_test_entry({"text": "[test] The trio animation is a lovely touch."}))
        self.assertTrue(drain.is_test_entry({"text": "  [test] leading space"}))
        self.assertFalse(drain.is_test_entry({"text": "A real note mentioning [test] later"}))
        self.assertFalse(drain.is_test_entry({"text": ""}))


class WhereItCameFrom(unittest.TestCase):
    def test_the_two_apps_are_named_differently(self):
        self.assertIn("an iPhone or iPad", drain.body_for("-k", entry(source="ios")))
        self.assertIn("a browser", drain.body_for("-k", entry(source="web")))

    def test_the_game_is_carried_when_there_is_one(self):
        self.assertIn("in Vibe Pairings", drain.body_for("-k", entry(game="Vibe Pairings")))
        self.assertNotIn("in ", drain.body_for("-k", entry()).split("Came from")[1].split(".")[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
