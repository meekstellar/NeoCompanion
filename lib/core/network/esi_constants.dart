const esiBaseUrl = 'https://esi.evetech.net';

/// CCP requires a User-Agent with developer contact info; missing it can
/// result in a ban without warning.
const esiUserAgent = 'NeoCompanion/0.1 (+contact: meekstellar@gmail.com)';

/// Key under which a request can carry the character whose token must be
/// attached. Read by [AuthInterceptor].
const esiCharacterIdKey = 'esiCharacterId';
