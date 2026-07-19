extends Node
## All game content, ported from Beat_The_Globetrotter_Godot_Handoff.docx.
## To change questions, edit this file only — everything else reads from it.
##
## Question shape:
##   kind: "mc" or "open"
##   text: question read aloud + shown on phones
##   options: 4 strings (mc only)
##   correct: index into options (mc only)
##   accepted: lowercase keywords, any match = correct (open only)
##   answer_text / fact: shown on reveal

const HERO_SPRITE := "res://assets/sprites/tile_0096.png"
const HERO_COLOR := Color(0.29, 0.89, 1.0) # cyan / electric blue

const BOSSES := [
	{
		"name": "SARAH",
		"title": "THE LOWLY ANALYTICS MANAGER",
		"taunt": "Still trying to figure out how Excel works",
		"sprite": "res://assets/sprites/tile_0085.png",
		"color": Color(1.0, 0.62, 0.19),       # warm orange
		"color2": Color(1.0, 0.82, 0.29),      # gold
		"arena": "desert",
		"questions": [
			{
				"kind": "mc",
				"text": "In which country is the Great Wall located?",
				"options": ["Japan", "China", "Mongolia", "South Korea"],
				"correct": 1,
				"answer_text": "B) China",
				"fact": "It stretches over 13,000 miles across northern China.",
			},
			{
				"kind": "mc",
				"text": "What is the official currency of the Eurozone (France, Germany, Italy, etc.)?",
				"options": ["Franc", "Mark", "Euro", "Lira"],
				"correct": 2,
				"answer_text": "C) Euro",
				"fact": "20 of the EU's 27 member states use it today.",
			},
			{
				"kind": "open",
				"text": "The Leaning Tower is in which Italian city?",
				"accepted": ["pisa", "piza"],
				"answer_text": "Pisa",
				"fact": "It started leaning during construction in the 1170s — and never stopped.",
			},
			{
				"kind": "mc",
				"text": "Which continent is also, confusingly, a single country?",
				"options": ["Antarctica", "Greenland", "Australia", "Iceland"],
				"correct": 2,
				"answer_text": "C) Australia",
				"fact": "The only continent governed by a single nation.",
			},
		],
		"overtime": {
			"kind": "mc",
			"text": "OVERTIME! Which ocean is the largest on Earth?",
			"options": ["Atlantic", "Indian", "Pacific", "Arctic"],
			"correct": 2,
			"answer_text": "C) Pacific",
			"fact": "It covers about a third of the planet's surface.",
		},
	},
	{
		"name": "KING CHINGUN",
		"title": "MASTER OF CROSSTABS",
		"taunt": "Has opinions about your weighting plan",
		"sprite": "res://assets/sprites/tile_0112.png",
		"color": Color(0.36, 0.78, 0.55),      # mossy green
		"color2": Color(0.29, 0.85, 0.80),     # teal
		"arena": "temple",
		"questions": [
			{
				"kind": "open",
				"text": "Name the city home to Christ the Redeemer, the giant statue overlooking the city from a mountaintop.",
				"accepted": ["rio"],
				"answer_text": "Rio de Janeiro, Brazil",
				"fact": "The statue stands 98 feet tall atop Corcovado Mountain.",
			},
			{
				"kind": "mc",
				"text": "Which country is home to the ancient city of Petra, carved into rose-colored sandstone cliffs?",
				"options": ["Egypt", "Jordan", "Morocco", "Israel"],
				"correct": 1,
				"answer_text": "B) Jordan",
				"fact": "Capital of the Nabataean Kingdom over 2,000 years ago.",
			},
			{
				"kind": "mc",
				"text": "What is technically the name of the famous bell inside London's clock tower — not the tower itself?",
				"options": ["Big Ben", "The Elizabeth Tower", "Westminster Bell", "The Great Clock"],
				"correct": 0,
				"answer_text": "A) Big Ben",
				"fact": "The tower itself is officially named the Elizabeth Tower.",
			},
			{
				"kind": "open",
				"text": "In which country would you find Bali, the popular island destination?",
				"accepted": ["indonesia"],
				"answer_text": "Indonesia",
				"fact": "Indonesia has over 17,000 islands total.",
			},
		],
		"overtime": {
			"kind": "mc",
			"text": "OVERTIME! Mount Everest sits on the border of Nepal and which other country?",
			"options": ["India", "China", "Bhutan", "Pakistan"],
			"correct": 1,
			"answer_text": "B) China",
			"fact": "The summit ridge runs right along the Nepal-Tibet (China) border.",
		},
	},
	{
		"name": "ASHLEY",
		"title": "BURRITO SUPREME LEADER",
		"taunt": "Making sure you've sent your milestones and accomplishments",
		"sprite": "res://assets/sprites/tile_0084.png",
		"color": Color(0.62, 0.36, 0.95),      # deep purple
		"color2": Color(1.0, 0.82, 0.29),      # gold
		"arena": "worldtour",
		"questions": [
			{
				"kind": "mc",
				"text": "Which country has held the title of \"world's most-visited country\" for more than 30 years running?",
				"options": ["Spain", "USA", "France", "Italy"],
				"correct": 2,
				"answer_text": "C) France",
				"fact": "About 102 million international visitors in 2024 alone.",
			},
			{
				"kind": "open",
				"text": "Name either endpoint city of the longest bookable nonstop commercial flight route in the world.",
				"accepted": ["new york", "newyork", "nyc", "jfk", "singapore"],
				"answer_text": "New York (JFK) or Singapore",
				"fact": "About 18h40m in the air — roughly 15,332 km.",
			},
			{
				"kind": "mc",
				"text": "Royal Caribbean's \"Icon of the Seas\" and \"Star of the Seas\" are the world's largest what?",
				"options": ["Airports", "Cruise ships", "Hotels", "Theme parks"],
				"correct": 1,
				"answer_text": "B) Cruise ships",
				"fact": "Each carries over 7,000 passengers at full capacity.",
			},
			{
				"kind": "open",
				"text": "Which country drinks the most coffee per person in the world?",
				"accepted": ["finland", "finnland"],
				"answer_text": "Finland",
				"fact": "Finns average about 4 cups a day — roughly 26 pounds of coffee per person a year.",
			},
		],
		"overtime": {
			"kind": "open",
			"text": "OVERTIME! Which country has the longest total coastline in the world?",
			"accepted": ["canada", "canda", "cannada"],
			"answer_text": "Canada",
			"fact": "About 151,000 miles of it — enough to circle the Earth six times.",
		},
	},
]

const QUESTIONS_PER_BOSS := 4

## Normalize a typed open-end answer for fuzzy matching.
static func normalize(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		var code := ch.unicode_at(0)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57):
			out += ch
		else:
			out += " "
	var parts := out.split(" ", false)
	return " ".join(parts)

## True if a typed answer matches any accepted keyword.
static func open_answer_correct(typed: String, accepted: Array) -> bool:
	var norm := normalize(typed)
	if norm.is_empty():
		return false
	var squashed := norm.replace(" ", "")
	for key in accepted:
		var k: String = normalize(str(key))
		if norm.contains(k) or squashed.contains(k.replace(" ", "")):
			return true
	return false
