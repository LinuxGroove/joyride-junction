# Screenshots

Every screen of Joyride Junction, at the game's own size (1280 x 800), made with Mesa's software Vulkan (mesa-vulkan-drivers) so they use the game's own renderer:

    VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --resolution 1280x800 tools/screenshot.tscn -- --all=docs/screenshots

- [Parks](#parks) (10)
- [Rides](#rides) (5)
- [Coaster builder](#coaster-builder) (22)
- [Building](#building) (11)
- [Windows](#windows) (8)
- [Menus](#menus) (18)

## Parks

Meadow Fair from its first day to its result, new sandbox parks on both maps, and a busy park with both ready-made coasters.

**Meadow Fair, day one.** The first scenario starts with a gate, a short path, a meadow of trees and $12,000. The tips say what to do first.

![Meadow Fair, day one](parks/meadow-fair-start.jpg)

**Meadow Fair, built up.** Two months in, with Little Woody, shops by the gate, benches, bins and a janitor.

![Meadow Fair, built up](parks/meadow-fair.jpg)

**Meadow Fair's goal.** The park window shows the goal and the deadline next to how the park is doing.

![Meadow Fair's goal](parks/meadow-fair-goal.jpg)

**Scenario complete.** Meeting the goal in time. The park stays open to keep building.

![Scenario complete](parks/meadow-fair-won.jpg)

**Out of time.** Missing the deadline. The park can still be played on.

![Out of time](parks/meadow-fair-lost.jpg)

**Sandbox on the Meadow.** A new sandbox park on the Meadow map, with no money to worry about.

![Sandbox on the Meadow](parks/sandbox-meadow.jpg)

**Sandbox on the Empty lot.** The Empty lot map: no trees, just the gate and a path.

![Sandbox on the Empty lot](parks/sandbox-empty-lot.jpg)

**A busy park.** Little Woody and Timber Twister both running, with queues, shops and a crowd.

![A busy park](parks/sunny-hollow.jpg)

**From above.** The same park with the camera tilted right down, as far out as it zooms.

![From above](parks/sunny-hollow-above.jpg)

**The crowd.** Close in on the shops by the gate: guests eating, queuing, resting and dropping litter.

![The crowd](parks/crowd.jpg)

## Rides

The ready-made coasters running, with their ride windows, and guests boarding.

**Little Woody.** A gentle family coaster with one hill.

![Little Woody](rides/little-woody.jpg)

**Little Woody's ride window.** Whether it's open, its queue, its ratings from the test run, and the ticket price and train length.

![Little Woody's ride window](rides/little-woody-window.jpg)

**Timber Twister.** A taller wooden coaster with two drops and wide turns.

![Timber Twister](rides/timber-twister.jpg)

**Timber Twister's ride window.** Whether it's open, its queue, its ratings from the test run, and the ticket price and train length.

![Timber Twister's ride window](rides/timber-twister-window.jpg)

**Boarding.** Guests queue from the footpath to the entrance, board at the station and leave by the exit.

![Boarding](rides/station.jpg)

## Coaster builder

Ready-made coasters and a station placed with the cursor, then a coaster built piece by piece: every kind of piece, one that won't go, the entrance and exit, and the finished ride.

**Placing Little Woody.** A ready-made coaster follows the cursor, green where it fits. Turn turns it.

![Placing Little Woody](builder/design-little-woody.jpg)

**Placing Timber Twister.** The bigger ready-made coaster, with its price beside the tool's name.

![Placing Timber Twister](builder/design-timber-twister.jpg)

**Where it won't fit.** Red where something's in the way, with the reason underneath.

![Where it won't fit](builder/design-blocked.jpg)

**A station.** Building your own coaster starts with a station. Turn turns it and Look changes its length.

![A station](builder/station.jpg)

**A station that won't go.** Stations need clear ground: not footpaths, shops or other rides.

![A station that won't go](builder/station-blocked.jpg)

**The track builder.** Track goes on piece by piece from the station. The panel picks the next piece's turn, slope and extras, and the ghost shows where it goes.

![The track builder](builder/track-start.jpg)

**A chain lift.** Chain lifts pull the train up. Slopes change one step at a time.

![A chain lift](builder/track-lift.jpg)

**Steep up.** From a slope, the next piece can go steeper.

![Steep up](builder/track-steep-up.jpg)

**Left.** At the top of the lift, flat again: a tight turn to the left.

![Left](builder/track-left.jpg)

**Wide left.** A wide turn takes more room and is gentler on riders.

![Wide left](builder/track-wide-left.jpg)

**Right.** A tight turn to the right.

![Right](builder/track-right.jpg)

**Wide right.** A wide turn to the right.

![Wide right](builder/track-wide-right.jpg)

**An unfinished coaster.** Stop building any time: the ride waits, closed, until its track comes back round to the station.

![An unfinished coaster](builder/unfinished.jpg)

**Down.** Over the top and down the other side.

![Down](builder/track-down.jpg)

**Steep down.** Steep drops make a ride more exciting, and more intense.

![Steep down](builder/track-steep-down.jpg)

**A piece that won't go.** Red means no, with the reason underneath: here the slope can only change one step at a time.

![A piece that won't go](builder/track-blocked.jpg)

**Brakes.** Brakes on the flat slow the train before the station.

![Brakes](builder/track-brakes.jpg)

**The last piece.** The ghost meets the station: one more piece closes the circuit.

![The last piece](builder/track-last-piece.jpg)

**The entrance.** With the circuit closed, the entrance goes beside the station: the yellow tiles are the places it can go.

![The entrance](builder/doors-entrance.jpg)

**The exit.** Then the exit, on another of the yellow tiles.

![The exit](builder/doors-exit.jpg)

**A finished coaster.** Its test run rates it for excitement, intensity and nausea. Lead a queue line to the entrance, then open it.

![A finished coaster](builder/finished.jpg)

**A queue line.** Queue lines run from a footpath to a ride's entrance.

![A queue line](builder/queue-line.jpg)

## Building

The build menu's tabs, and the tools for footpaths, queue lines, shops, scenery and the bulldozer.

**Build menu: Paths.** Footpaths, and queue lines that lead to rides.

![Build menu: Paths](building/menu-paths.jpg)

**Build menu: Rides.** The wooden coaster to build yourself, and the two ready-made ones.

![Build menu: Rides](building/menu-rides.jpg)

**Build menu: Shops.** Food, drinks, toilets and the information kiosk.

![Build menu: Shops](building/menu-shops.jpg)

**Build menu: Scenery.** Benches, bins, trees, flowers and tall grass.

![Build menu: Scenery](building/menu-scenery.jpg)

**Build menu: Clear.** The bulldozer.

![Build menu: Clear](building/menu-clear.jpg)

**Footpaths.** Hold the button and move to keep laying. Guests only walk on footpaths.

![Footpaths](building/path.jpg)

**Queue lines.** Queue lines lead from a footpath to a ride's entrance.

![Queue lines](building/queue.jpg)

**A shop.** Shops go beside a footpath and turn to face it.

![A shop](building/shop.jpg)

**Scenery.** Trees, flowers and benches. Turn turns them.

![Scenery](building/scenery.jpg)

**A shop that won't go.** Shops need a footpath next to them.

![A shop that won't go](building/shop-blocked.jpg)

**The bulldozer.** Clears a tile and gives half its price back. Hold the button to keep clearing.

![The bulldozer](building/bulldozer.jpg)

## Windows

A shop, a guest, the park's money and staff, renaming, and the pause menu.

**A shop.** What it sells, what it has taken and its price.

![A shop](windows/shop.jpg)

**A guest.** What they're doing, what they think, their money and their needs.

![A guest](windows/guest.jpg)

**The park.** The rating, guests, happiness and the date, the goal, the entry fee and renaming.

![The park](windows/park-park.jpg)

**Money.** This month's money in and out, and last month's.

![Money](windows/park-money.jpg)

**Staff.** The janitors, to hire or let go.

![Staff](windows/park-staff.jpg)

**Renaming a ride.** Rides, and parks, take any name up to 24 letters.

![Renaming a ride](windows/rename-ride.jpg)

**The pause menu.** The park stops while it's open: save, how to play, tips, autosave, or back to the title screen.

![The pause menu](windows/pause.jpg)

**How to play, from the pause menu.** The same pages as on the title screen, over the park.

![How to play, from the pause menu](windows/pause-howto.jpg)

## Menus

The title screen, the park library, new parks, settings, about and every page of How to play.

**Welcome.** The first time the game starts: the tutorial, or straight into Meadow Fair.

![Welcome](menus/welcome.jpg)

**The title screen.** Carry on with the last park, or pick another. The sample park runs behind the menus.

![The title screen](menus/title.jpg)

**Your parks.** Every park is kept, with a picture from when it was last saved, most recently played first.

![Your parks](menus/library.jpg)

**A saved park.** Play it, copy it, rename it or delete it.

![A saved park](menus/park.jpg)

**Renaming a park.** A name box that works with a controller too.

![Renaming a park](menus/rename.jpg)

**Deleting a park.** Deleting asks first. The other parks stay.

![Deleting a park](menus/delete.jpg)

**New park.** Start a scenario, or a sandbox on either map.

![New park](menus/new.jpg)

**Meadow Fair.** The scenario's story, goal and starting money.

![Meadow Fair](menus/scenario.jpg)

**Naming a sandbox park.** Sandbox parks get a name before they start.

![Naming a sandbox park](menus/sandbox-name.jpg)

**Settings.** The shared settings, plus tips during play and how often to autosave.

![Settings](menus/settings.jpg)

**About.** Credits and licenses.

![About](menus/about.jpg)

**How to play: Your park.** Page 1 of 7.

![How to play: Your park](menus/howto-1.jpg)

**How to play: Paths and shops.** Page 2 of 7.

![How to play: Paths and shops](menus/howto-2.jpg)

**How to play: Coasters.** Page 3 of 7.

![How to play: Coasters](menus/howto-3.jpg)

**How to play: Ratings.** Page 4 of 7.

![How to play: Ratings](menus/howto-4.jpg)

**How to play: Happy guests.** Page 5 of 7.

![How to play: Happy guests](menus/howto-5.jpg)

**How to play: Your parks are kept.** Page 6 of 7.

![How to play: Your parks are kept](menus/howto-6.jpg)

**How to play: Controls.** Page 7 of 7.

![How to play: Controls](menus/howto-7.jpg)
