# Campaign Support Hub API contract

The app's Campaign Support Hub (`lib/features/alumni_running/`) is built against
this contract. The Django endpoints do not exist yet. Until they ship, demo
builds use `DemoCampaignRepository`, which holds fictional candidates only.

Every endpoint requires the normal `Authorization: Token <token>` header. The
server is the authorization boundary. The app only hides or shows controls, and
it treats `403` as authoritative.

## Privacy rules (server and client)

Supporting a campaign is political-opinion data.

- Joining a channel and signing up for a shift are explicit, opt-in actions.
- Never expose who belongs to a channel or who signed up for a shift. That
  means no member lists, no per-person supporter data, and no "X joined" system
  messages. A supporter is visible only through messages they post in a channel
  they joined.
- Never put membership, sign-ups, candidate names, or races in push
  notifications, analytics, or request logs. Push text for channel messages is
  always exactly: `New message in a campaign channel`.
- Do not add demographic or identity fields to candidates or supporters.
- The app keeps this data only in memory for the authenticated session. It is
  cleared on sign-out and is never written to SharedPreferences.

## Candidates

Staff curate candidates in the Django admin. The app reads them and never
writes them.

`GET /api/campaigns/candidates/` returns `200` with a list. The list may also
come wrapped in a `{"results": [...]}` envelope.

```json
{
  "id": "42",
  "name": "Full Name",
  "office": "Kentucky State Senate, District 6",
  "election_name": "2026 general election",
  "election_date": "2026-11-03",
  "status": "running",
  "bio": "Short public bio.",
  "van_id": 12345,
  "campaign_url": "https://example.org",
  "donate_url": "https://example.org/donate",
  "volunteer_url": "https://example.org/volunteer",
  "info_url": "https://ballotpedia.org/...",
  "headshot_url": "https://<media origin>/media/candidates/42.jpg",
  "win_post": {"group_id": 1, "post_id": 9}
}
```

Field rules:

- `id` and `name` are required. Items without them are skipped.
- All other fields are optional.
- `status` is one of `running`, `won_primary`, `won`, or `did_not_win`. Any
  other value is shown as an unknown status.
- URLs must be `https`. The app drops any other URL and hides its button.
- `headshot_url` must be on the configured media origin. Otherwise the app
  drops it.
- `win_post` points to the community post where alumni congratulate a winner.
  It is used only when `status` is `won_primary` or `won`.

## Supporter channels

`GET /api/campaigns/channels/` returns `200` with only the caller's own
memberships:

```json
[{"candidate_id": "42", "channel_id": "opaque-server-id"}]
```

- `POST /api/campaigns/candidates/{id}/channel/join/` returns `200` with the
  membership object above. It is idempotent.
- `DELETE /api/campaigns/candidates/{id}/channel/membership/` returns `204`.
  Leaving must always be possible. The app also treats `403` and `404` here as
  "already left".

Messages use the existing chat endpoints and the existing `ChatMessage` shape:

- `GET /api/chat/{channel_id}/messages`
- `POST /api/chat/{channel_id}/messages`
- WebSocket `/ws/chat/{channel_id}/`

All three must return `403` (or close the socket) for anyone who is not a
member. When the app gets a `403`, it drops the membership locally and shows
the Join button again.

## Volunteer shifts

`GET /api/campaigns/candidates/{id}/shifts/` returns `200` with a list of shift
objects:

```json
{
  "id": "s1",
  "candidate_id": "42",
  "kind": "canvass",
  "title": "Saturday canvass",
  "starts_at": "2026-10-10T14:00:00Z",
  "ends_at": "2026-10-10T17:00:00Z",
  "location": "Meet at the campaign office",
  "capacity": 20,
  "remaining": 7,
  "signed_up": false
}
```

- `kind` is one of `canvass`, `phone_bank`, `event`, or `other`.
- `signed_up` describes only the caller.
- `GET /api/campaigns/my-shifts/` returns `200` with the caller's signed-up
  shifts. The Events calendar shows them, marked as campaign shifts.
- `POST /api/campaigns/shifts/{id}/signup/` returns `201` with the updated
  shift. Return `409` when the shift is full.
- `DELETE /api/campaigns/shifts/{id}/signup/` returns `200` with the updated
  shift.

## Seed data

These are the live candidates that used to be hardcoded in the app. Load them
into the backend, never into demo data. Check each URL and status before
seeding.

| Name | Office | Status | Links |
| --- | --- | --- | --- |
| Christian Furman | Kentucky State Senate, District 6 | `won_primary` | `campaign_url`: https://christianforky.com/, `info_url`: https://ballotpedia.org/Christian_Furman |
| Amy Olson | St. Matthews City Council, At-large | `running` | `info_url`: https://ballotpedia.org/Amy_Olson_(Saint_Matthews_City_Council_At-large,_Kentucky,_candidate_2026) |
| Serenity Johnson | Radcliff City Council, At-large | `running` | `info_url`: https://ballotpedia.org/Serenity_Johnson_(Radcliff_City_Council_At-large,_Kentucky,_candidate_2026) |

All three run in the general election on 2026-11-03.
