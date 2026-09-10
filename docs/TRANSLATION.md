# Live content translation

English is an excerpt of the linked institutional source. Chinese and Korean are produced by Apple's on-device Translation framework. Full language coverage is required before adding a card. This avoids mixing incomplete language entries in the library, but does not establish translation correctness.

The first live test exposed specific mistranslations: generic galactic merger became 银河系合并, image field became 字段, and superbubble became 超级泡沫. `AstronomyTerms` applies a small source-conditioned glossary and Traditional-to-Simplified conversion. References to the Milky Way, our galaxy, and Galactic Centre/Center are excluded from the generic galaxy correction. Other terms and grammar may still need human correction; the app identifies machine-translated material.

References used for the corrections and implementation:

- [National Astronomical Observatories research news](https://www.nao.cas.cn/news/ky/index_1.html): 超泡 terminology.
- [Korea Institute for Advanced Study astronomy lecture](https://www.kias.re.kr/files/B0000037/202401/54dd9edbf5234ea1baf8a09968d126dc.pdf): 대마젤란 은하 / Large Magellanic Cloud terminology.
- [Apple TranslationSession](https://developer.apple.com/documentation/translation/translationsession): installed-language and view-bound sessions.
- [Apple: Translating text within your app](https://developer.apple.com/documentation/Translation/translating-text-within-your-app): language availability, permission and batch translation.

The package does not use a cloud LLM, user API keys, or a generative-image service. Original images are downloaded from the credited institutional CDN. Local cards and machine translations are not automatically uploaded to GitHub or to the other application.
