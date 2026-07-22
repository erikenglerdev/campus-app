// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

/// Fixtures shaped exactly like the responses in `docs/api.md`.
///
/// All names are fictional demo data and are marked as such where the contract
/// provides a flag for it. No real person, phone number or e-mail address
/// appears anywhere in this file.
library;

List<Map<String, dynamic>> get channelsFixture => <Map<String, dynamic>>[
  <String, dynamic>{
    'slug': 'campus-news',
    'name': 'Campus News',
    'description': 'Nachrichten rund um den Campus Köthen.',
    'iconKey': 'campus',
    'colorHex': '#5B3FD0',
    'sortOrder': 10,
    'defaultSubscribed': true,
  },
  <String, dynamic>{
    'slug': 'fb5-news',
    'name': 'FB5 News',
    'description': null,
    'iconKey': 'unknown-icon-key',
    'colorHex': null,
    'sortOrder': 20,
    'defaultSubscribed': true,
  },
];

List<Map<String, dynamic>> get articlesFixture => <Map<String, dynamic>>[
  <String, dynamic>{
    'slug': 'semesterstart-2026',
    'title': 'Semesterstart 2026',
    'teaser': 'Was zum Start des Wintersemesters wichtig ist.',
    'publishedAt': '2026-07-20T09:00:00.000Z',
    'isPinned': true,
    'heroImage': null,
    'channels': <Object>[
      <String, dynamic>{
        'slug': 'campus-news',
        'name': 'Campus News',
        'colorHex': '#5B3FD0',
      },
    ],
    'authors': <Object>[],
    'sourceName': null,
    'sourceUrl': null,
  },
];

Map<String, dynamic> get canteenFixture => <String, dynamic>{
  'slug': 'koethen-fasanerieallee',
  'displayName': 'Mensa Köthen',
  'campusLabel': 'Fasanerieallee',
  'lastSuccessfulSyncAt': '2026-07-22T12:00:04.000Z',
  'dataStale': false,
};

/// A menu whose only day is [date], containing one meal with three price
/// groups, a sprint marker, extras, ingredients and markers.
Map<String, dynamic> menuFixture(DateTime date) => <String, dynamic>{
  'canteen': <String, dynamic>{
    'slug': 'koethen-fasanerieallee',
    'displayName': 'Mensa Köthen',
    'campusLabel': 'Fasanerieallee',
  },
  'days': <Object>[
    <String, dynamic>{
      'date':
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
      'meals': <Object>[
        <String, dynamic>{
          'id': '58033',
          'name': 'Bulgur-Pfanne',
          'subtitle': 'mit Kichererbsen, Wirsing und Kräuterdip',
          'sourceLanguage': 'de',
          'counterId': 44,
          'isSprint': true,
          'extras': <Object>['Salatbeilage'],
          'markers': <Object>[
            <String, dynamic>{
              'code': '52',
              'label': 'vegan',
              'kind': 'ingredient',
            },
            <String, dynamic>{
              'code': '53',
              'label': 'Sprint-Menü',
              'kind': 'marker',
            },
          ],
          'prices': <Object>[
            <String, dynamic>{
              'group': 'student',
              'label': 'Studierende',
              'amount': '1.95',
              'currency': 'EUR',
            },
            <String, dynamic>{
              'group': 'employee',
              'label': 'Bedienstete',
              'amount': '4.95',
              'currency': 'EUR',
            },
            <String, dynamic>{
              'group': 'guest',
              'label': 'Gäste',
              'amount': '7.00',
              'currency': 'EUR',
            },
          ],
        },
      ],
    },
  ],
};

/// A contact area without any person and with almost every field unmaintained.
Map<String, dynamic> get emptyContactAreaFixture => <String, dynamic>{
  'slug': 'studierendenrat',
  'name': 'Studierendenrat',
  'shortDescription': 'Die gewählte Vertretung der Studierendenschaft.',
  'iconKey': 'students-council',
  'sortOrder': 10,
  'generalEmail': null,
  'phone': null,
  'website': null,
  'appointmentUrl': null,
  'address': null,
  'openingHours': null,
  'personCount': 0,
  'isDemoContent': true,
  'description': <Object>[],
  'persons': <Object>[],
};

/// A contact area whose `iconKey` is unknown to the app.
Map<String, dynamic> get unknownIconAreaFixture => <String, dynamic>{
  'slug': 'unbekannt',
  'name': 'Neuer Bereich',
  'shortDescription': null,
  'iconKey': 'a-key-the-app-has-never-seen',
  'sortOrder': 20,
  'personCount': 0,
  'isDemoContent': false,
};
