# WeddingOS Guest Import Template

Status: Version-controlled template contract for `STORY-09-01` / `TOP-GUE-004`.

The Flutter app generates the downloadable `.xlsx` file from these approved flat-row columns. Raw `.xlsx` files are parsed locally on device and are not uploaded or stored in backend/cloud storage.

## Sheet

`WeddingOS Guests`

## Columns

| Order | Column Name | Required | Notes |
| :--- | :--- | :--- | :--- |
| 1 | `Guest Name` | Yes | Individual Guest display name. Max 50 characters. |
| 2 | `Phone` | No | Used for strong duplicate warning after normalization. |
| 3 | `Email` | No | Used for duplicate warning after lowercase normalization. |
| 4 | `Side` | Yes | `COMMON`, `BRIDE_SIDE`, or `GROOM_SIDE`. |
| 5 | `PrimaryGroup` | No | Exact same-Wedding name mapping; missing groups are shown in Preview and created once on Confirm. |
| 6 | `Party Key` | No | The only import grouping key. Blank means the Guest remains unassigned. |
| 7 | `Party Display Name` | Required when `Party Key` is present | Party-level fact. Must be consistent across rows sharing a Party Key. |
| 8 | `Invited Count` | Required when `Party Key` is present | Positive integer; independent from named Guest count. |
| 9 | `Guest Source` | Yes | `BRIDE`, `GROOM`, `BRIDE_PARENTS`, `GROOM_PARENTS`, or `OTHER`. Unknown labels require Preview mapping before Confirm. |

## Excluded Columns

The template intentionally does not include Guest Owner, global Contact ID, fake companion rows, RSVP fields, invitation credentials, finance fields, or media fields.
