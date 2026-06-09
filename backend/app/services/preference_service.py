### The preference service uses user interactions to adjust what the user sees.
## This is distinct from other services because
## it is modifying the feed instead of getting it.

class PreferenceService:
    def updateFromInteractions(self, prefs, interactions):
        topicScores = {}

        for i in interactions:
            if i.liked:
                topicScores[i.topic] = topicScores.get(i.topic, 0) + 1

            if prefs.use_view_time:
                topicScores[i.topic] = topicScores.get(i.topic, 0) + (i.view_time * prefs.view_time_weight)

        sortedTopics = sorted(topicScores.items(), key=lambda x: x[1], reverse=True)

        # topic level learning only!
        prefs.preferredTopics = [t[0] for t in sortedTopics[:5]]

        return prefs
