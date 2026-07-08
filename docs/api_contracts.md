Frontend should return something like:

{
  "strategy_weights": {
    "similar": 0.5,
    "graph": 0.2,
    "opposite": 0.2,
    "random": 0.1
  },
  "randomness": 0.3,
  "diversity_tolerance": 40,
  "topic_preferences": [
    {"topic": "tech", "preference_type": "preferred"},
    {"topic": "startups", "preference_type": "preferred"},
    {"topic": "politics", "preference_type": "blacklisted"}
  ]
}