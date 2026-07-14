Frontend should return something like:

{
  "strategy_weights": {
    "similar": 0.4,
    "graph": 0.25,
    "opposite": 0.2,
    "random": 0.15
  },
  "randomness": 0.4,
  "diversity_tolerance": 0.4,
  "topic_preferences": [
    {"topic": "technology", "preference_type": "preferred"},
    {"topic": "politics", "preference_type": "blacklisted"}
  ],
  "ai_topic_detection": false
}

Graph session (`GET /feed/me/session?diversify=true|false`) returns:

{
  "posts": [ /* Post objects */ ],
  "seed_strategy": "soft_prior | diversify | random | …",
  "diversify": false
}
