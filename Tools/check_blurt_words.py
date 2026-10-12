#!/usr/bin/env python3
"""Validates the Vibe Blurt pack files.

The Blurt words are read out loud and guessed at, so they have to be short and
sayable; and they are read by an American table, so they have to be the words an
American would use. That second one is the reason this file exists: the pack was
written in British English by accident, and "wellies" and "suncream" are not
words a player in Ohio can describe to anybody.

Checks, per pack:
  * at least MIN_PER_PACK entries
  * no duplicates within the pack, and none across the whole library
  * 1-4 words, letters/spaces/hyphens/apostrophes only, no trailing punctuation
  * first letter capitalised, not SHOUTED
  * no British-only words, and no British spellings
  * no entry containing its own pack's theme word

Usage: python3 Tools/check_blurt_words.py
Exits non-zero if any check fails.
"""
import re
import sys
from pathlib import Path

PACKS_DIR = Path("Sources/Features/VibeBlurt/Packs")
MIN_PER_PACK = 240
MIN_TOTAL = 2000
MIN_WORDS, MAX_WORDS = 1, 4

EXPECTED = {
    "FoodWords": "food",
    "AnimalsWords": "animals",
    "PlacesWords": "places",
    "HouseholdWords": "household",
    "PeopleWords": "people",
    "PlayWords": "play",
    "ActionsWords": "actions",
    "OccasionsWords": "occasions",
}

# The word an entry must not contain, because describing it would be the game
# given away: the Animals pack cannot contain "animal".
THEME_WORD = {
    "food": "food",
    "animals": "animal",
    "places": "place",
    "household": "house",
    "people": "job",
    "play": "sport",
    "actions": "action",
    "occasions": "celebration",
}

# Words that are British and nothing else: not the thing an American would call
# it, so a table here would be describing something nobody has a name for. Only
# names with no American life at all belong here — "tap", "vest", "pudding" and
# "chips" are all ordinary American words, so they are advisories below rather
# than failures.
BRITISH_WORDS = [
    "wellies", "wellie", "wellington boots", "suncream", "yoghurt", "postman",
    "postie", "dustman", "dustmen", "car park", "cinema", "harbour",
    "shopping centre", "shopping centres", "paddling pool", "fairy lights",
    "snooker", "crumpet", "crumpets", "lorry", "lorries", "nappy", "nappies",
    "pram", "dustbin", "courgette", "courgettes", "aubergine", "aubergines",
    "coriander", "prawn", "prawns", "crisps", "fizzy drink", "petrol",
    "motorway", "windscreen", "takeaway", "trolley", "fortnight", "whilst",
    "amongst", "learnt", "headmaster", "headmistress", "candy floss",
    "candyfloss", "ice lolly", "serviette", "noughts and crosses", "draughts",
    "zebra crossing", "high street", "off-licence", "lay-by",
    "dual carriageway", "car boot sale", "plimsolls", "plimsoll", "tuppence",
    "pinafore", "aeroplane", "aerodrome", "gramophone", "wash-basin",
    "cotton wool", "drawing pin", "biro", "tippex", "sellotape", "hoover",
    "washing-up liquid", "clothes peg", "bedside table", "bin liner",
    "oven glove", "icing sugar", "gobstopper", "lolly", "lollies",
    "spring onion", "beetroot", "swede", "bobby", "bobbies", "jelly baby",
    "sherbet", "spotted dick", "bubble and squeak", "toad in the hole",
    "yorkshire pudding", "black pudding", "clotted cream", "double cream",
    "digestive biscuit", "sultanas", "dungarees", "plait", "plaiting",
    "wellington", "jellybabies", "candyfloss stick", "cooking apple",
    "washing powder", "airing cupboard", "boiler suit", "chrimbo",
]

# British spellings, with the American next to them so the message can say what
# to write instead. Matched as whole words, case-insensitively.
BRITISH_SPELLINGS = {
    "colour": "color", "colours": "colors", "coloured": "colored",
    "favourite": "favorite", "favourites": "favorites",
    "flavour": "flavor", "flavours": "flavors",
    "behaviour": "behavior", "behaviours": "behaviors",
    "harbour": "harbor", "harbours": "harbors",
    "honour": "honor", "honours": "honors",
    "humour": "humor", "labour": "labor", "neighbour": "neighbor",
    "neighbours": "neighbors", "rumour": "rumor", "rumours": "rumors",
    "savour": "savor", "splendour": "splendor", "tumour": "tumor",
    "valour": "valor", "vapour": "vapor", "vigour": "vigor",
    "endeavour": "endeavor", "armour": "armor", "clamour": "clamor",
    "glamour": "glamor", "odour": "odor", "parlour": "parlor",
    "rigour": "rigor", "saviour": "savior", "behavioural": "behavioral",
    "centre": "center", "centres": "centers", "theatre": "theater",
    "theatres": "theaters", "metre": "meter", "metres": "meters",
    "litre": "liter", "litres": "liters", "fibre": "fiber",
    "calibre": "caliber", "sombre": "somber", "spectre": "specter",
    "lustre": "luster", "manoeuvre": "maneuver", "meagre": "meager",
    "sabre": "saber", "sceptre": "scepter", "mitre": "miter",
    "realise": "realize", "realised": "realized", "realising": "realizing",
    "organise": "organize", "organised": "organized", "organising": "organizing",
    "recognise": "recognize", "recognised": "recognized",
    "apologise": "apologize", "apologised": "apologized",
    "criticise": "criticize", "criticised": "criticized",
    "memorise": "memorize", "socialise": "socialize", "specialise": "specialize",
    "summarise": "summarize", "prioritise": "prioritize",
    "normalise": "normalize", "categorise": "categorize",
    "customise": "customize", "emphasise": "emphasize",
    "energise": "energize", "fantasise": "fantasize", "hypnotise": "hypnotize",
    "maximise": "maximize", "minimise": "minimize", "mobilise": "mobilize",
    "modernise": "modernize", "neutralise": "neutralize",
    "optimise": "optimize", "paralyse": "paralyze", "popularise": "popularize",
    "publicise": "publicize", "randomise": "randomize",
    "rationalise": "rationalize", "sterilise": "sterilize",
    "symbolise": "symbolize", "sympathise": "sympathize",
    "utilise": "utilize", "visualise": "visualize",
    "organisation": "organization", "organisations": "organizations",
    "civilisation": "civilization", "speciality": "specialty",
    "grey": "gray", "greys": "grays", "tyre": "tire", "tyres": "tires",
    "kerb": "curb", "plough": "plow", "draught": "draft", "gaol": "jail",
    "storey": "story", "storeys": "stories", "cheque": "check",
    "cheques": "checks", "aluminium": "aluminum", "pyjamas": "pajamas",
    "moustache": "mustache", "yoghurt": "yogurt", "plummet": "plummet",
    "travelling": "traveling", "travelled": "traveled", "traveller": "traveler",
    "travellers": "travelers", "cancelled": "canceled", "cancelling": "canceling",
    "labelled": "labeled", "labelling": "labeling", "modelled": "modeled",
    "modelling": "modeling", "fuelled": "fueled", "jewellery": "jewelry",
    "marvellous": "marvelous", "woollen": "woolen", "cosy": "cozy",
    "practise": "practice", "licence": "license", "defence": "defense",
    "offence": "offense", "pretence": "pretense", "maths": "math",
    "dialogue": "dialog", "catalogue": "catalog", "analogue": "analog",
    "judgement": "judgment", "acknowledgement": "acknowledgment",
    "ageing": "aging", "likeable": "likable", "sizeable": "sizable",
    "storeyed": "storied", "programme": "program", "tonne": "ton",
    "spelt": "spelled", "learnt": "learned", "burnt": "burned",
    "dreamt": "dreamed", "leapt": "leaped", "smelt": "smelled",
    "amongst": "among", "whilst": "while", "towards": "toward",
    "afterwards": "afterward", "forwards": "forward", "backwards": "backward",
}

# Ordinary American words that mean something different in Britain, so a pack can
# end up describing the wrong thing. Not fatal — "Chips" in a Food pack is a real
# American entry — but worth seeing, because the British sense is usually the one
# that got written down.
CONFUSING = ["chips", "biscuit", "football", "hockey", "jumper", "trainers",
             "queue", "queuing", "plaster", "cot", "dummy", "tap", "vest",
             "pudding", "jelly", "rubber", "braces", "supper", "grill",
             "socket", "flannel", "marrow", "mince", "squash", "trousers",
             "rocket", "holiday", "purse", "boot", "cider", "banger",
             "sweets", "chemist", "garden", "campsite", "roundabout", "cooker",
             "estate agent",
             "football boots", "vest top", "pants"]

# Brand and trademark names. A party game that prints somebody's trademark on a
# card is borrowing it, so the words are generic kinds of thing only. Only
# unambiguous brand strings are here: "clue", "risk", "sorry" and "operation" are
# also ordinary English words, so those are left to the reviewer.
BRANDS = [
    "monopoly", "scrabble", "pictionary", "jenga", "uno", "battleship",
    "yahtzee", "rubik's cube", "rubiks cube", "boggle", "connect four",
    "trivial pursuit", "twister", "lego", "legos", "barbie", "hot wheels",
    "nerf", "play-doh", "playdoh", "slinky", "etch a sketch", "spirograph",
    "silly putty", "beanie baby", "tamagotchi", "game boy", "xbox",
    "playstation", "nintendo", "minecraft", "fortnite", "pokemon", "disney",
    "marvel", "star wars", "coca-cola", "coca cola", "pepsi", "mcdonald's",
    "burger king", "kfc", "starbucks", "skittles", "snickers", "oreo",
    "cheetos", "doritos", "pringles", "nutella", "heinz", "kellogg's",
    "frosted flakes", "cheerios", "pop tart", "gatorade", "powerade",
    "red bull", "kleenex", "band-aid", "q-tip", "jacuzzi", "jell-o",
    "velcro", "ziploc", "tupperware", "post-it", "sharpie", "crayola",
    "google", "iphone", "ipad", "youtube", "netflix", "instagram", "tiktok",
]

problems: list[str] = []
advisories: list[str] = []
seen: dict[str, str] = {}
total = 0

print(f"{'pack':20s} {'count':>5s}  status")
print("-" * 44)

for type_name, pack_id in EXPECTED.items():
    path = PACKS_DIR / f"{type_name}.swift"
    if not path.exists():
        problems.append(f"{type_name}: file missing ({path})")
        print(f"{type_name:20s} {'--':>5s}  MISSING")
        continue

    source = path.read_text()
    body = re.search(r"static let all: \[String\] = \[(.*?)\n    \]", source, re.S)
    if not body:
        problems.append(f"{type_name}: could not find the `static let all` array")
        print(f"{type_name:20s} {'--':>5s}  UNPARSEABLE")
        continue

    items = re.findall(r'"((?:[^"\\]|\\.)*)"', body.group(1))
    total += len(items)

    local_problems: list[str] = []
    if len(items) < MIN_PER_PACK:
        local_problems.append(f"count {len(items)} < {MIN_PER_PACK}")

    local_seen: set[str] = set()
    for item in items:
        if item in local_seen:
            local_problems.append(f"duplicate within pack: {item!r}")
        local_seen.add(item)

        if item in seen:
            local_problems.append(f"also in {seen[item]}: {item!r}")
        else:
            seen[item] = pack_id

        words = item.split()
        if not (MIN_WORDS <= len(words) <= MAX_WORDS):
            local_problems.append(f"{len(words)} words: {item!r}")
        if item != item.strip():
            local_problems.append(f"stray whitespace: {item!r}")
        if not re.fullmatch(r"[A-Z][A-Za-z\u00c0-\u024f'\- ]*", item):
            local_problems.append(f"unexpected characters: {item!r}")
        # Initialisms like RSVP are correctly upper case; a whole shouted
        # phrase is not.
        if item == item.upper() and len(item) > 5:
            local_problems.append(f"shouting: {item!r}")
        if THEME_WORD[pack_id] in item.lower().split():
            local_problems.append(f"contains the theme word {THEME_WORD[pack_id]!r}: {item!r}")

        lowered = item.lower()
        for bad in BRITISH_WORDS:
            if re.search(rf"\b{re.escape(bad)}\b", lowered):
                local_problems.append(f"British word {bad!r} in {item!r}")
        for bad in BRANDS:
            if re.search(rf"\b{re.escape(bad)}\b", lowered):
                local_problems.append(f"brand name {bad!r} in {item!r}")
        for word in re.findall(r"[a-z]+", lowered):
            if word in BRITISH_SPELLINGS:
                local_problems.append(
                    f"British spelling {word!r} in {item!r} — write {BRITISH_SPELLINGS[word]!r}")
        for word in CONFUSING:
            if re.search(rf"\b{re.escape(word)}\b", lowered):
                advisories.append(f"{pack_id}: {item!r} — {word!r} means something else in Britain")

    if local_problems:
        problems.extend(f"{pack_id}: {p}" for p in local_problems)
        print(f"{type_name:20s} {len(items):>5d}  {len(local_problems)} PROBLEM(S)")
    else:
        print(f"{type_name:20s} {len(items):>5d}  ok")

print("-" * 44)
print(f"{'total':20s} {total:>5d}")

if total < MIN_TOTAL:
    problems.append(f"only {total} words in the library, want at least {MIN_TOTAL}")

if advisories:
    print(f"\n{len(advisories)} word(s) worth a second look (not failures):")
    for note in advisories[:40]:
        print(f"  {note}")

if problems:
    print(f"\n{len(problems)} problem(s):")
    for problem in problems[:60]:
        print(f"  {problem}")
    if len(problems) > 60:
        print(f"  ... and {len(problems) - 60} more")
    sys.exit(1)

print("\nBlurt words check passed.")
