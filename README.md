# Librarian

Library book tracker for **WoW Forever**. Forever hides 40 lore books around Azeroth; hand them to
the librarian (Garion Wendell in Stormwind, Owen Thadd in Undercity) for the *Friend of the
Library* (10 books) and *Greater Friend of the Library* (20 books) rewards. Librarian shows which
ones you still need, where they are, and what you get.

## Features

- **Journal** (`/librarian`, the minimap button or the addon compartment)
  - Progress toward both rewards, with a goal bar.
  - Three summary cards: the first unfinished book in your current zone, the recommended next
    book, and your next reward.
  - Every book in a card, grouped *In bags*, *Missing* and *Delivered* and sorted by zone level:
    zone, level range, faction, container, place and coordinates.
- **Book page**: click any book to see its details and notes, the other books of the same zone,
  and an embedded zone map with every book of the zone pinned (mouse wheel zooms, drag pans).
  From there, set a waypoint or mark the book by hand.
- **Rewards page**: every reward choice for both quests. Choices that do not suit your class
  or talent spec are dimmed. Pick the one you want, and see where your librarian stands
  ("Show on Map").
- **World map pins** for the books you are missing, on zone and continent maps (optionally the
  ones in your bags too). Click = waypoint, Shift-click = the book's page.
- **Zone toast** when you enter a zone with a missing book (once per zone per session).
- **Objective tracker section** listing the current zone's missing books and the books waiting
  to be turned in.
- **TomTom** waypoints when TomTom is installed; Blizzard's map pin otherwise.
- **Automatic detection**: a book is *delivered* once its turn-in quest is completed, *in bags*
  while you carry it. Manual marks (per character) cover a turn-in the game does not report.
- **Localised**: English and Spanish (esES / esMX). Book, quest, zone and item names come from
  your game client.

## Commands

- `/librarian`: open or close the journal
- `/librarian zone [name]`: list a zone's books in chat
- `/librarian all`: progress per zone
- `/librarian mark <book> bags|delivered|clear`: manual mark
- `/librarian options`: options
- `/librarian probe`: raw detection data (for bug reports)

## Data sources

Book locations and notes are compiled from
[foreverchanges.pro](https://foreverchanges.pro/library-books), [Wowhead](https://www.wowhead.com)
(WoW Forever) and [zockify.com](https://zockify.com/forever/library-books), with thanks to the
players who reported them. Found a book somewhere else? Open an issue with the zone and
coordinates.

## License

MIT, see [LICENSE](LICENSE).
