# Emerge KY platform: groups + moderation build spec

Companion to `emerge_ky_seed.json` (383 alumnae, 24 groups). Borrowed from TransWell (`mspaldingworks/transwell_api`, `transconnectky_api`).

## Seed import rules

- One `CustomUser` per `alumni[]` row, `is_active=False` until claimed; `program_year` = `class_year`; role `alumni`, tier 1 (never staff/superuser — the Phase 0 fix).
- `claim.email` is null by design. Fill it at import from Emerge's own records (VAN My Campaign), match on `seed_id`, then send a one-time claim link. Covered by the alumni data agreement (open blocker #2).
- `claim.status = memorial` (4 deceased alumnae): never send an invite; render a memorial profile.
- Render the candidate card (campaign / volunteer / donate buttons) only when `candidacy_2026.show_on_card` is true. Medium/low-confidence rows are name matches awaiting staff confirmation.
- Hide `candidacy_2026` from cards after 2026-11-03; keep it as history.

## Groups (TransWell pattern)

TransWell keeps one statewide group plus one group per region, keyed by `Group.region_id` with the keys in `region_utils.REGION_DEFINITIONS`. Reuse the same keys so `region_utils.py` ports unchanged, and add one cohort group per class year.

| slug | name | type | region_id | program_year | members seeded | membership rule |
|---|---|---|---|---|---|---|
| `emky-statewide` | Emerge KY Statewide | statewide | statewide | — | 383 | everyone, auto-join |
| `emky-region-louisvilleSouthernIndiana` | Emerge KY — Louisville / Kentuckiana | regional | louisvilleSouthernIndiana | — | 120 | auto-join from county → region; may join others |
| `emky-region-northernKY` | Emerge KY — Northern KY | regional | northernKY | — | 34 | auto-join from county → region; may join others |
| `emky-region-centralKY` | Emerge KY — Central KY | regional | centralKY | — | 80 | auto-join from county → region; may join others |
| `emky-region-easternKY` | Emerge KY — Eastern KY | regional | easternKY | — | 25 | auto-join from county → region; may join others |
| `emky-region-southCentralKY` | Emerge KY — South Central KY | regional | southCentralKY | — | 34 | auto-join from county → region; may join others |
| `emky-region-westernKY` | Emerge KY — Western KY | regional | westernKY | — | 34 | auto-join from county → region; may join others |
| `emky-class-2010` | Class of 2010 | cohort | — | 2010 | 20 | auto-join where program_year matches |
| `emky-class-2011` | Class of 2011 | cohort | — | 2011 | 23 | auto-join where program_year matches |
| `emky-class-2012` | Class of 2012 | cohort | — | 2012 | 17 | auto-join where program_year matches |
| `emky-class-2013` | Class of 2013 | cohort | — | 2013 | 22 | auto-join where program_year matches |
| `emky-class-2014` | Class of 2014 | cohort | — | 2014 | 17 | auto-join where program_year matches |
| `emky-class-2015` | Class of 2015 | cohort | — | 2015 | 18 | auto-join where program_year matches |
| `emky-class-2016` | Class of 2016 | cohort | — | 2016 | 19 | auto-join where program_year matches |
| `emky-class-2017` | Class of 2017 | cohort | — | 2017 | 24 | auto-join where program_year matches |
| `emky-class-2018` | Class of 2018 | cohort | — | 2018 | 28 | auto-join where program_year matches |
| `emky-class-2019` | Class of 2019 | cohort | — | 2019 | 28 | auto-join where program_year matches |
| `emky-class-2020` | Class of 2020 | cohort | — | 2020 | 28 | auto-join where program_year matches |
| `emky-class-2021` | Class of 2021 | cohort | — | 2021 | 26 | auto-join where program_year matches |
| `emky-class-2022` | Class of 2022 | cohort | — | 2022 | 18 | auto-join where program_year matches |
| `emky-class-2023` | Class of 2023 | cohort | — | 2023 | 21 | auto-join where program_year matches |
| `emky-class-2024` | Class of 2024 | cohort | — | 2024 | 22 | auto-join where program_year matches |
| `emky-class-2025` | Class of 2025 | cohort | — | 2025 | 26 | auto-join where program_year matches |
| `emky-class-2026` | Class of 2026 | cohort | — | 2026 | 22 | auto-join where program_year matches |

County → region map (alumnae with no county sit in statewide only until one is added):

- **louisvilleSouthernIndiana** (Louisville / Kentuckiana): Jefferson, Oldham, Bullitt, Shelby, Spencer, Henry, Trimble
- **northernKY** (Northern KY): Boone, Kenton, Campbell, Grant, Pendleton, Bracken, Gallatin, Carroll, Owen
- **centralKY** (Central KY): Fayette, Scott, Woodford, Franklin, Jessamine, Madison, Clark, Bourbon, Anderson, Mercer, Boyle, Garrard, Montgomery, Nelson, Washington, Marion, Harrison, Lincoln
- **easternKY** (Eastern KY): Pike, Perry, Breathitt, Magoffin, Boyd, Greenup, Rowan, Morgan, Knox, Whitley, Powell, Fleming, Mason, Floyd, Letcher, Harlan, Bell, Laurel, Lawrence, Carter, Elliott, Estill, Lee, Wolfe, Johnson, Martin, Lewis
- **southCentralKY** (South Central KY): Warren, Barren, Hardin, Larue, Simpson, Logan, Hart, Grayson, Breckinridge, Meade, Pulaski, Adair, Green, Taylor, Metcalfe, Monroe, Allen, Butler, Edmonson, Cumberland, Clinton, Russell, Wayne, Casey
- **westernKY** (Western KY): McCracken, Calloway, Christian, Graves, Marshall, Daviess, Henderson, Muhlenberg, Todd, Hopkins, Hancock, Union, Webster, Ohio, Caldwell, Trigg, Lyon, Livingston, Crittenden, Ballard, Carlisle, Hickman, Fulton

Cohort membership must key on `CustomUser.program_year`, not space membership — `sync_cohort_groups` currently enrols everyone in every cohort space.

## Moderation control panel (staff + superusers)

| area | feature | behavior | TransWell source | NPO-Community note |
|---|---|---|---|---|
| Access | Who sees the panel | Staff (is_staff) and superusers. Reuse TransWell IsModeratorOrAdmin for the panel; superuser-only actions use IsAdminLikeUser. | permissions.py IsModeratorOrAdmin / IsAdminLikeUser | Map to NPO-Community capability chat:moderate (seeded, unused) + admin role |
| Profile claims | Claim queue | Pending claims, invite sent/opened/claimed, resend invite, approve mismatched-email claims by hand. | views/account_approval_views.py → admin/account-approvals/ (+ approve, reject, audit) | Replaces TransWell signup approval; claims match seed claim.email |
| Members | Member list + search | Filter by class year, region, role, status; open a member to act. | AdminUserListView → admin/users/ |  |
| Members | Warn / restrict / suspend / ban | Graduated actions with a required reason; each writes to the audit log. Protected targets (staff, superusers) cannot be actioned by staff. | admin/users/<pk>/warn/restrict/suspend/ban/ + _is_protected_target() |  |
| Members | Lift restriction | Superuser only. | admin/users/<pk>/lift-restriction/ (IsAdminLikeUser) |  |
| Roles | Make moderator / make admin | Superuser only. In NPO-Community route through the audited assign_role() service rather than flags. | admin/users/<pk>/set-moderator/, set-admin/ | role_management.assign_role() |
| Content | Reports queue | Reports on posts, comments and DMs in one queue; resolve, dismiss, or escalate to a member action. | ContentReport model + admin/flagged-content/ | Fills the missing block/report gap named in the platform proposal (Phase 2) |
| Content | Image screening | Optional automatic NSFW check on uploads. | moderation/check-image/ (CheckImageView) | Optional for an alumni network |
| Groups | Group approval queue | Approve/reject member-created groups; class and regional groups are seeded pre-approved. | admin/groups/approval-queue/ + approve/reject |  |
| Groups | Group console | Group admins: settings, announcements, polls, events. | groups/<pk>/console/settings/announcements/polls/events/ | Badges optional |
| Audit | Audit log | Every moderation action, role change and full-contact profile read, filterable by actor and target. | admin/audit-log/ | NPO-Community AuditLog already records P2 reads |
