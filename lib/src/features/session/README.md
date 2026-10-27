# Session Feature

The implemented controller owns one session and injected transport. It serializes
mutations, checks revisions, rejects expired/disabled submissions, handles
ambiguous outcomes and ignores late responses after disposal. Native exchange,
HTTP, autosave and evidence recovery are implemented in the transport. No Origin spoofing.
