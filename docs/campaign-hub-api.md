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

Candidates are curated in the Django admin for now. Staff can also manage
them in the app (see [Candidate management](#candidate-management)).

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

## Candidate management

Admins use the Django admin. Staff who should manage candidates without
admin access get the in-app editor, which uses these endpoints.

### Permission

Grant the Django model permissions `campaigns.add_candidate`,
`campaigns.change_candidate` and `campaigns.delete_candidate`, for example
through a "Campaign curators" group. Do not derive the grant from `is_staff`
or a role name.

`GET /api/campaigns/permissions/` returns `200`:

```json
{"can_manage_candidates": true}
```

`can_manage_candidates` is `true` only when the user holds
`campaigns.change_candidate`. The app fails closed: any error, a missing
field, or a non-boolean value means no management controls. Management is
also always off in demo builds and during Role Preview.

### Writes

The request body for create and update holds the editable candidate fields:

- `name` and `office` are required.
- Every other field may be `null`, which clears it.
- `status` is never sent as unknown.
- `headshot_url` and `win_post` stay admin-only and are never sent.

| Method and path | Success | Response |
| --- | --- | --- |
| `POST /api/campaigns/candidates/` | `201` | The created candidate |
| `PATCH /api/campaigns/candidates/{id}/` | `200` | The updated candidate |
| `DELETE /api/campaigns/candidates/{id}/` | `204` | Empty |

Server requirements:

- Check the matching model permission on every write and return `403`
  without it. A `403` hides the editor until the next sign-in.
- Validate that every URL is `https`.
- Deleting a candidate also removes their supporter channel and volunteer
  shifts.
- Never notify users about candidate edits.

## Seed data

These candidates were cross-checked against Ballotpedia and local election
coverage on 2026-10-01. The general election is on 2026-11-03.

- Load them into the backend, never into demo data.
- Confirm Emerge Kentucky alumni status with program staff before
  publishing. The research could only confirm it where the notes column
  says so.
- Ballotpedia links marked † were not seen in a search result and should be
  opened once before seeding.

### Running

| Name | Office | Status | `campaign_url` | `info_url` | Notes |
| --- | --- | --- | --- | --- | --- |
| Christian Furman | Kentucky State Senate, District 6 | `won_primary` | https://christianforky.com/ | https://ballotpedia.org/Christian_Furman | Won the Democratic primary 76.5%–23.5% over Chaz Stoess. Faces incumbent Lindsey Tichenor (R). Alumni status from the program. |
| Anne Donworth | Kentucky House, District 76 | `won_primary` | https://www.annegaydonworth.com/ | https://ballotpedia.org/Anne_Donworth † | Incumbent. Won the Democratic primary 61.1%–38.9% over James Palumbo. Faces Avram Hicks (R). Her campaign site names her as an Emerge Kentucky alum. |
| Nima Kulkarni | Kentucky House, District 40 | `won_primary` | | https://ballotpedia.org/Nima_Kulkarni † | Incumbent. Won the Democratic primary 77.4%–22.6% over Patrick Bryant Dunegan. Unopposed in November. Listed by Emerge Kentucky as in elected office. |
| Karen Berg | Kentucky State Senate, District 26 | `running` | | https://ballotpedia.org/Karen_Berg | Incumbent. Primary canceled (unopposed). Faces Everett Corley (R). Emerge Kentucky class of 2017. |
| Tina Bojanowski | Kentucky House, District 32 | `running` | | https://ballotpedia.org/Tina_Bojanowski | Incumbent. Primary canceled (unopposed). Listed by Emerge Kentucky as in elected office. |
| Lindsey Burke | Kentucky House, District 75 | `running` | | https://ballotpedia.org/Lindsey_Burke | Incumbent. Primary canceled. Faces Jeff Forsyth (R) and Geoff Young (Kentucky Party). Listed by Emerge Kentucky as in elected office. |
| Shameka Parrish-Wright | Mayor of Louisville | `running` | https://shamekaforlouisville.com/ † | https://ballotpedia.org/Shameka_Parrish-Wright | Metro Council District 3. Finished second (26.3%) in the nonpartisan top-two primary and faces Mayor Craig Greenberg. Listed by Emerge Kentucky as in elected office. |
| Shayla Lynch | Lexington Urban County Council, District 2 | `running` | | https://ballotpedia.org/Shayla_Lynch | Incumbent. Unopposed. Listed by Emerge Kentucky as in elected office. |
| Dana Beasley-Brown | Bowling Green City Commission, At-large | `running` | | https://ballotpedia.org/Dana_Beasley-Brown_(Bowling_Green_City_Commission_At-large,_Kentucky,_candidate_2026) | Incumbent. Listed by Emerge Kentucky as in elected office. |
| Lisa Johnson | Versailles City Council | `running` | | https://ky.emergeamerica.org/alumna/lisa-johnson/ | Incumbent. On the Woodford County 2026 sample ballot. No Ballotpedia page found. Has an Emerge Kentucky alumna page. |
| Amy Olson | St. Matthews City Council, At-large | `running` | | https://ballotpedia.org/Amy_Olson_(Saint_Matthews_City_Council_At-large,_Kentucky,_candidate_2026) | Incumbent since 2018. Alumni status from the program. |
| Serenity Johnson | Radcliff City Council, At-large | `running` | | https://ballotpedia.org/Serenity_Johnson_(Radcliff_City_Council_At-large,_Kentucky,_candidate_2026) | Advanced from the May 19 primary (top 12 of 14 for 6 seats). Alumni status from the program. |

Use `won_primary` only for a nomination win. Advancing from a nonpartisan
top-two or top-N primary stays `running`, so the Wins feed doesn't celebrate
it.

### Checked and not seeded

| Name | Why |
| --- | --- |
| Pamela Stevenson | Not running for House District 43 again. Ran for U.S. Senate and lost the Democratic primary. |
| Beverly Chester-Burton | Lost the House District 44 Democratic primary to Kenya Wade. |
| Monica Mundy | Fayette County school board term runs to 2029. |
| Sarah Froelich | Not on a 2026 ballot. |
| Cassie Chambers Armstrong, Keturah Herron | Odd-numbered Senate districts aren't up until 2028. |
| Jacqueline Coleman | Lieutenant Governor; next election is 2027. |
| Brenda Monarrez | Running for Lexington Council District 4, but no Emerge Kentucky affiliation found. |

### Needs confirmation from program staff

Search results reported these legislators as Emerge Kentucky alumni running
in 2026. The same results also listed someone who has already retired, so
check each name with the alumni roster and Ballotpedia before seeding:

- Rachel Roberts (House 67)
- Lisa Willner (House 35)
- Sarah Stalker (House 34)
- Rachel Roarx (House 38)
- Adrielle Camuel

The search also found no published Emerge Kentucky "On the Ballot in 2026"
page. The program's own roster is the best way to find newer alumni running
locally, including the class of 2026.
