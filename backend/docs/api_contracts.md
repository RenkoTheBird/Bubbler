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
  "preferred_topics": ["tech", "startups"],
  "blacklisted_topics": ["politics"]
}