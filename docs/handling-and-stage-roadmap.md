# Paper Rally handling and stage roadmap

## Yet to implement

This is the active backlog. Update it in the same change that ships, replaces or verifies an item. Move completed work into the release notes below and retain any open device or player checks here. The older reports record decisions and baselines.

### P0 · Resolve on-device reliability and timing

| Outstanding work | Evidence and first step | Acceptance |
| --- | --- | --- |
| Confirm controller release on the reported handset | The 4.4.1 input code can shift a physical zero to 0.5. The new readout shows the engine and effective pedal values. Capture the controller model, transport and readings before a press, on release, and on the next RT press. Cover one Xbox-format pad, one PlayStation-format pad and one USB-C attachment. | Release LT without using RT and watch Brake return to 0%. Then check acceleration and brake lamps. Repeat after pause, reconnect and when touch controls remain visible. Keep the test trace with the build. |
| Measure sustained Android rendering and simulation | The project has an FPS counter and desktop benchmarks. It still needs per-frame timings and device data. Capture frame time, fixed-step CPU and memory on rainy Harbour, an Alpine night tunnel, and a six-car Marathon at 30/60 fps. Track elapsed time separately from simulated time during a forced stall. | Publish p50/p95/p99 frame times, worst consecutive frames and memory after repeated retries on at least a low- and mid-tier handset. Record any green corruption with weather, camera, GPU, setting changes and frame trace. |
| Verify stage timing and recovery | The race clock advances in fixed steps with a capped frame delta. Finish uses projected station. Measure timing under stalls and test adjacent road legs before introducing competitive results. Define what resets and missed controls do to a time-trial result. | The same clean drive gets the same time at different rendering rates. A shortcut onto a later leg cannot record a finish. Reset and off-course rules are visible in the result. |
| Prepare a release pipeline if Play distribution is chosen | The audited 1.0.11 APK targets API 34. Its arm64 Godot and C++ libraries have 4 KiB ELF load alignment. Android compatibility guidance calls for a 16 KiB check of the native libraries as well as package alignment. Create a repeatable signed test artifact and a separate store build specification. | Verify package, version, signature and supported ABIs in CI. Test an upgrade that retains saves. For Play, confirm its current target SDK and AAB requirements, check 16 KiB ELF alignment, and boot on a 16 KiB device or emulator. |
| Share saved pictures on Android | Photo mode captures a PNG and tries direct file paths. Prototype the system sharing flow and shared media insertion for modern Android. Report write failures accurately. | Save and share from photo mode on a scoped-storage Android version. The photo is visible in the gallery when requested and UI returns even if writing fails or the player backs out. |

### P1 · Make it easier to learn and improve

| Outstanding work | Smallest worthwhile prototype | Acceptance |
| --- | --- | --- |
| Split times, usable comparisons and ghost provenance | Split a Sprint into three timed sectors. Compare deltas with the player's best valid run. Ghost data currently holds poses and a stage signature. Store the recording version and car identity alongside route, lighting and reset rules. | At each split the delta agrees with the saved sector times. A replay or ghost identifies the car that set the time. Older pose-based ghosts still play where the route matches. |
| Practice and short challenges | Build three short exercises on existing roads. Cover an ice stop, a crest landing and a gravel hairpin. Start immediately before the exercise with fixed weather and car, and show one measurable goal. | Each exercise can be retried with one action. Teach one input at a time using the player's current bindings. Players can leave for the normal race flow at any point. |
| Accessible controls and HUD | Add remappable gameplay actions, left-handed touch placement, size/contrast options and a reduced-motion setting for camera shake and UI. Retain alternate digital pedal actions. | A controller and touch player can configure options and complete a race using their chosen layout. The start and finish on the map, split direction and warning severity remain distinguishable without colour alone. |
| Tyre and surface progression | Measure the current four tyre contacts before introducing temperature or wear. Start with selectable gravel/tarmac/snow compounds and a clearly explained wet-tarmac versus loose-gravel trade-off. | Repeat a braked hairpin, split-grip launch and long downhill across equal-spec cars. Keep baseline response close enough that touch players can learn one race at a time. |
| Setup, functional damage and service | The existing suspension supports different travel presets and cars already deform visually. Prototype one axle-limited setup adjustment and two readable damage states, such as a damaged lamp and damaged steering. Try timed repairs between two championship legs. | Each change has a consistent effect, a report at parc fermé and a clear repair path. Default setup remains usable. Existing championships and saves load normally. |
| Consistent AI and attainable medals | Profiles already use estimated traction, and some automated trial runs finish outside gold. Collect clean human runs per drivetrain and add reproducible AI seeds. Review medals by route, car class and weather before adjusting them. | Run at least one dry, wet and snowy Sprint across FWD/RWD/AWD. Record medians and spread. Inspect hairpin braking and bridge approaches in a human-versus-AI pack. |

### P2 · Make individual routes more memorable

| Outstanding work | Smallest worthwhile prototype | Acceptance |
| --- | --- | --- |
| More localised surface and environmental effects | Repeat the original visual checks for broken ice print, drying cobbles, pier wakes and snowbank scuffs. Prioritise matching the texture boundary to physical grip. Add one shared wind direction before adding emitters. | Check rainy harbour and ice from bonnet and high chase. Wheel tracks follow the actual surface. A parked car stops emitting spray, and the extra effects fit the device frame budget. |
| Material-specific damage and remaining cockpit details | Follow up the existing panel deformation, neutral silhouette tests and shift lamps. Give the same strike a different shape on a painted wing, lamp insert and plastic bumper. Reserve close cockpit details for places outside the apex sightline. | At matched classic and modern front-quarter impacts the struck part is readable. In snow and at dusk, gauges remain readable at the default 58° FOV. |

### Follow-up validation

| Outstanding work | Acceptance |
| --- | --- |
| Co-driver and crossing mix on Android | Judge the new pace-note clips over engine and rain on a phone speaker and headphones. Check Late, Normal, Early, Off and the separate voice volume. Timber, stone and steel joints should remain distinct, and the tunnel reflection should be audible at crawl and race speeds. |
| Compare co-driver voices in play | Check all five voice packs on Android with engine and weather active. Compare clarity and phrasing at matched playback level. Check dense corners and long turn-to-hazard calls with each timing option. |
| Blind chapter and preview recognition | Give drivers unlabelled screenshots of Slate Gorge, Autumn Ridge, Harbour Lanes and Alpine Pass. Check whether they can put each set in route order and recognise a landmark without the setup description. Confirm the Slate Gorge Classic preview distinguishes the stacked truss from the other spans. |
| Autumn leaf litter on Android | Drive over a wide drift at low speed, pass it at racing speed and park beside it. Check that the wake affects the nearby leaves and the far edge stays down. Repeat in bonnet and low chase, then check frame pacing on Autumn Ridge Marathon with a full AI pack and low and high particle settings. |
| Android audio and closer vehicle matches | Listen to the four recorded families on a phone speaker and headphones. Start with Nimbus Turbo on gravel and Harbour Lanes. Check a full pull, an analog lift, trail braking, throttle reapplication and a call over the tyres. Compare against the supplied clips at matched loudness. Refine model-specific donor recordings and add separate intake and gearbox layers where they are audible. Review snow, cobbles and impact material sounds after the engine mix. |
| Continue the exterior reference pass | Compare the Stiletto, Pip and Lynx in neutral paint and normal chase at phone size. Next try the long-hood classic coupe, squared Group A hatch, and a compact modern hatch with a short overhang and clearer greenhouse. |
| Region-specific approaches | Prototype one forestry opening in Pinewood Deluge and one slipway approach in Harbour Lanes. Check the location reads before the bend in cockpit and low chase. Give the props a physical purpose and room around the racing line. |
| More stacked routes, if the Classic opening holds up in play | Drive the Classic crossing with a pack, recover at each deck and play back a saved ghost. Check the overhead cutaway from photo mode and the two road surfaces in rain or darkness before adding another stacked route. |

### P3 · Extend repeat play after the foundations

| Outstanding work | Smallest worthwhile prototype | Acceptance |
| --- | --- | --- |
| Full local replay viewer | The best ghost is a pose stream, while photo mode pauses the live race. Record one Sprint with a final time, a short event timeline and two landmark camera cuts. Add pause, scrubbing and photo mode from the replay. | Seek repeatedly across a jump, impact and lighting change. Restore car, lighting and effects consistently without resimulating current physics. |
| Custom rally and regularity | Let players string together three existing routes with one car and a time-of-day rule. Test a separate regularity target driven by consistent pace. | Resume a partially completed offline rally and reproduce the result. The target pace and penalties are visible before starting the event. |
| Career, free drive and online events | The roster and stages are open, and championship points already exist. Prototype an optional offline set of era objectives first. Assess demand for untimed exploration and shared challenges after race validation and replay versioning. | Basic offline racing stays immediately accessible. Shared leaderboards, if introduced, define valid laps, version comparisons and the handling of interrupted submissions before any public rollout. |

Android's controller guide documents duplicate trigger channels and devices that send button events instead of analog events. Godot's documentation also says SDL3 desktop controller support and Android controller support follow different paths. A desktop engine upgrade alone is therefore insufficient evidence for the reported Android device. [Android controller input](https://developer.android.com/games/sdk/game-controller/controller-input) · [Godot controller support](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html)

Use Android's frame pacing and thermal guidance to design the device benchmark. Verify store packaging against the current requirements when shipping, and use MediaStore for gallery-visible photos. [Android frame rates](https://developer.android.com/games/optimize/framerate) · [Thermal API](https://developer.android.com/games/optimize/adpf/thermal) · [Target SDK requirements](https://developer.android.com/google/play/requirements/target-sdk) · [16 KB page sizes](https://developer.android.com/guide/practices/page-sizes) · [Shared media](https://developer.android.com/training/data-storage/shared/media)

The most transferable reference features are adjustable co-driver lead and short training exercises from EA SPORTS WRC, and the combination of results, replay and photo sharing shown by art of rally. For control and HUD review, use the Xbox guidelines on input choices and redundant cues. These are references for Paper Rally's original designs. [EA SPORTS WRC features](https://www.ea.com/games/ea-sports-wrc/wrc/news/deep-dive-features) · [EA accessibility options](https://www.ea.com/able/resources/ea-sports-wrc) · [art of rally](https://store.steampowered.com/app/550320/Art_of_rally/) · [Xbox accessibility guidelines](https://learn.microsoft.com/gaming/accessibility/guidelines)

## Selectable co-driver voices · 1.0.20

Audio & Haptics has a saved co-driver voice choice with Blake, Darren, James, Nick and Stephane. Each pack has 137 calls, including complete turn-to-hazard phrases. Blake is the default. The existing voice timing and volume controls apply to every pack.

## Engine rev playback · 1.0.19

Each RPM recording now plays through its own audio player. The previous mixer stored Godot's 64-bit voice IDs as 32-bit values, so gain and pitch updates missed the higher bands and left an idle-like note in the mix. A desktop engine-bus capture now tracks a pull, a lift and a second pull. Confirm the change in chase and cockpit on the reported Android handset.

## Lift-off, tyre feedback and cockpit fit · 1.0.18

The player engine keeps the recorded power and overrun loops running through lift-off, braking and the next throttle input. Downshifts keep the engine mix up. A turbo exhaust shot can follow a gradual high-RPM lift, as well as a quick one. Rolling sounds sit higher in the mix, gravel uses a separate recorded scrub for slides, and the road tyre sound responds to slide and brake load. The engine ducks under full-phrase British English co-driver clips rendered offline. [Recording credits](../audio/recorded/ATTRIBUTION.md) · [Pace-note credits](../audio/codriver/ATTRIBUTION.md)

The cockpit shares the exterior bonnet mesh and windscreen outline, so bonnet shapes, livery, vents and collision dents carry through from the outside. The open Sandhopper uses its exposed exterior from the driver's seat.

## Recorded engine and road audio · 1.0.17

Four real-recording families cover compact, boxer, turbo and heavy engines. The player's engine crossfades five RPM bands in separate power and coast banks. Exhaust pitch follows a fixed ratio per gear. Opponents use the same family recordings with positional sound.

Recorded wet tyres and gravel blend with wheel loading and road speed. Turbo cars use three recorded anti-lag transients at high-RPM lift-off. Source and licensing information travels with the game. [Recording credits](../audio/recorded/ATTRIBUTION.md)

The RevoluSound pack is a reference for separating intake, exhaust, turbo and shift sounds. Its published terms forbid conversion for other games and require permission to reuse individual assets. [RevoluSound Team Pack](https://www.nexusmods.com/forzahorizon6/mods/56?tab=description)

## Exterior and engine reference pass · 1.0.16

The supplied car reel shows a low wedge with raised lamp housings and a louvred rear, a short classic hatch with thin brightwork, and a later rally hatch with a long sloped rear screen. The Stiletto HF, Pip 1300 and Lynx Turbo now use those cues in their own folded-paper bodywork. The revised body shells run through the garage, player, rivals and photo mode.

FFmpeg and frequency-over-time plots show short pitch drops between rising phrases in the supplied engine clips, plus longer sustained pulls. The `093128` clip was about 24 dB quieter at peak than the other examples. The engine now eases between load and overrun, dips through a shift and has separate harmonic balances by car family. Cockpit mode softens upper frequencies and the engine ducks gently during co-driver calls. The in-game sound comes from the existing licensed loop and procedural layers.

Public test builds can be published with `tools/publish_test_apk.sh`. The script verifies the download against the signed local APK before returning its GitHub URL.

## Wider autumn drifts · 1.0.15

Autumn Ridge's road and verge drifts now contain 59–83 individual leaves per collection. Two overlapping pockets spread the leaves lengthwise along the bend and across the shoulder. The car still lifts leaves according to proximity and speed, with the existing particle budget limiting the number in flight. Godot checks cover the broadened drifts and settling on all four routes.

## Audio and scenery reference pass

- Paper Rally's shared engine source is an eight-second stereo loop, pitched with RPM and backed by a synthesised load layer. A source-level FFmpeg check put the engine's highest sample at −0.8 dBFS and the impact clip at −1.2 dBFS. Measure the summed in-game output under a shift, impact and co-driver call before choosing mix levels. Keep editable WAV takes for future engine recording sessions. [Current sound implementation](../scripts/autoload/sfx.gd)
- Forza's developers describe rebuilding real engine recordings into layers that respond to the physics, and using separate microphones for the intake, exhaust, transmission and cabin. A small first pass for Paper Rally is an engine and exhaust recording under power and on lift-off, with an interior transmission layer. Ease between sources over RPM and load, then audition one car from chase and cockpit at matched output level. [Forza Motorsport audio update](https://forza.net/news/forza-motorsport-audio-updates) · [Forza recording discussion](https://forza.net/news/in-the-garage-audio-discord-ama)
- EA's Latvia stage notes describe narrow forest sections on Vecpils. Use the change in sightline on Pinewood Deluge by opening a wet forestry turnout between two close stands of trees. Put a drainage headwall at the mouth and group cut timber beyond the bend, reusing the existing forestry meshes. On Harbour Lanes, give the approach to the existing waterfront a working slipway with mooring rings and a weathered winch. Keep heavy props on supported ground and give standing water a visible outlet. [EA SPORTS WRC 24 Gameplay Deep Dive](https://www.ea.com/games/ea-sports-wrc/wrc-24/news/wrc24-gameplay-deep-dive)
- The supplied DiRT Rally 2.0 / WRC comparison is a candidate for matching throttle and gear events. The Polo R forest run can guide a separate review of speed, sightlines and loose-surface feedback. The workspace could identify those clips by title. Playback of the supplied videos is pending. [Sound comparison](https://www.youtube.com/shorts/vcQn11NKhts) · [Polo R forest run](https://www.youtube.com/watch?v=rtaWeNOeluU)

## Route chapters and leaf litter · 1.0.14

All distances on Alpine Pass move from wooded slopes through the ski-lift slopes and out onto exposed snowfields. Harbour Lanes moves from the working waterfront through the fishing village to the open headland. Autumn Ridge starts in vineyard lanes, closes in through copper woods and opens up on the final ridge. Ground palettes and scenery weights blend between chapters. The stage confirmation screen shows the sequence.

Autumn Ridge has seeded leaf drifts on the road and verges, with more drifts in the wooded section. A slow tyre pass lifts a few leaves. At speed the wake also catches leaves beside the car, and those leaves tumble and settle in new positions. Both player and AI cars can scatter them. The weather-particle setting limits simultaneous flight and the draw-distance setting controls their visibility.

## Co-driver, crossings and route previews · 1.0.13

**Settings → Audio & Haptics** offers Off, Late, Normal and Early for co-driver timing, a separate voice volume, and a Crossing sounds switch. Lead increases with speed. A closely following hazard can share a single call, such as “three left into tunnel”. Voice playback cancels on pause, finish or recovery and skips notes the car has passed. Crossing sounds use short procedural timber, stone and steel impacts at axle crossings, plus a damped reflection at tunnel and underpass entrances.

The optional scripts are `scripts/race/co_driver_voice.gd` and `scripts/race/crossing_audio.gd`. Removing either script hides its Settings controls and skips its race setup. Remove `audio/codriver/` as well to drop the voice assets. The pace-note cards and race logic work independently.

Race vs AI confirmation offers **Impact with AI**. Off disables contact between the player and rival cars. Rivals still interact with one another and scenery. Time Trial confirmation offers **Show ghost**. Off hides the previous run and still records new best runs.

Slate Gorge Classic now drives under its own truss about 124 m from the start and returns over it about 548 m from the start. The two decks are roughly 8.6 m apart. The revised Classic route keeps its nominal 8 km distance. It uses a new record key, so the old layout's records remain separate. All four Slate Gorge variants progress through warm scree, dark vertical slate and pale layered rock. Overhead views reveal the car beneath the truss and road-level cameras show the structure.

All 44 route variants have a separate in-game preview. Each confirmation screen shows the route map, elevation profile and total ascent for the selected distance. The map honours the authored crossing and the elevation line uses the same grades and hazards as the race.

Automated tests checked both decks at the same horizontal position with the wrong initial projection hint. An AI driver completed both passes and continued onto the original route. Same-deck car contact followed the Race vs AI setting. The voice timing and combined call, stale-call cancellation, and the axle joint trigger were checked in Godot. The phone-speaker mix and player recognition remain open above.

## Controller and Settings update · 1.0.12

Settings now uses a plain text heading. The Controls tab shows engine LT/RT values next to the effective pedals. Auto recognises the Android mapping that shifts a trigger's physical release to 0.50. **Zero rest** and **Half rest** let players select the range manually. **Brake with X only** is available for a controller that never reports a usable LT release.

Accelerating suppresses LT until it returns to neutral, even across a throttle release. X remains available for deliberate brake overlap. The fixed-step regression released the brake and brake lights at the mapped 0.50 value with no accelerator. With LT then held at a stale 0.95 reading, RT accelerated the test car from 6.93 to 11.41 m/s. Device verification remains open in the backlog above. [Godot's trigger conversion in 4.4.1](https://github.com/godotengine/godot/blob/4.4.1-stable/core/input/input.cpp#L1307-L1314) · [Godot's Android midpoint report](https://github.com/godotengine/godot/issues/79263)

## Handling and race setup · 1.0.11

The location card now opens a race setup page. The map follows the selected Sprint, Classic, Long or Marathon route, with green for the start and red for the finish. A player can return to the same location card with B. Only **Start race** commits the distance and time of day. Directional focus follows the rows on the location grid, route setup and settings screens.

**Sunset** starts in daylight and ends at night. **Sunrise** starts at night and ends in daylight. Both move through a low, warm sun and finish the transition at 94% of the course. Track progress controls the sky, ambient light, headlights, street lamps and colour grade. Reversing and resetting leave the sky at the furthest point reached during the run.

A fresh accelerator press overrides an unchanged controller brake reading. A fresh brake press can still slow the car during acceleration. Automated checks simulated a left trigger remaining at 85% after the driver switched to the accelerator. Speed recovered from 6.93 to 11.44 m/s and the brake lamps went out. The release still needs confirmation on the affected Android controller.

### Drivetrain and suspension priorities in the current build

| Priority | Implementation |
|---|---|
| Fixed-tick telemetry | The handling trace writes the normalised controls, delivered service brake, four tyre surfaces and loads, front and rear force and slip, and the two suspension offsets. |
| Drive, braking and combined grip | Drive reaches the configured axles. Each wheel's longitudinal force reduces its lateral grip budget. Front and rear lateral forces are limited separately. Longitudinal acceleration moves load forward or rearward. |
| Tyres and differentials | Each tyre samples patches and verges. The open differential and limited-slip model share a torque budget. AWD can move some surplus torque to the axle with spare grip. |
| Pedals and gearbox | The service brake has front bias. The handbrake reduces rear grip and releases progressively. Gear torque blends across shifts. Closed throttle adds engine braking, and a deliberate brake hold at a standstill engages reverse. |
| Ride | Front and rear springs use different compression and rebound damping, limited travel and progressive stops. Hard surfaces use shorter travel. Body heave, pitch and roll interpolate between physics ticks. Wheel contact informs the debris and separate suspension sound. |
| Race balance and saves | AI and medal calculations use the vehicle's traction profiles. Existing ghosts replay stored positions on the same road. |

The equal-spec Frozen Lakes launch reached 4.14 m/s in FWD, 4.71 m/s in RWD and 9.52 m/s in AWD after 1.5 seconds. The Meadow crest test recorded a period with one axle supporting the car at each of the three approach speeds. Device frame times and controller behaviour still need a run on the affected handset.

The ground animals introduced in 1.0.10 were removed. The existing birds remain.

## November 2026 field update · 1.0.10

The favourite Slate Gorge sequence works because the driver can see another part of the route before taking the return bend. The bridge then provides a clear destination. The new sections apply that timing to existing return legs and keep their original centreline and road height.

| Route | Distance from the start | What to look for |
|---|---:|---|
| Sandstone Canyon Sprint | 3.77 km | Descend toward a sandstone-coloured tunnel with striped portals and warm wall lights. |
| Sandstone Canyon Classic | 2.15 km | The return leg crosses a dry ravine on a steel truss. |
| Autumn Ridge Classic | 4.04 km | The lower return leg follows the wooded cutting into a 40 m tunnel. |
| Alpine Pass Classic | 0.29 km | The opening switchback descends into a short snow-covered tunnel. |

The high chase and overhead photo angles can see through a tunnel roof when the car is inside. Cockpit and low chase still show the bore. The tunnel walls use the same collision path as roadside barriers. Ghost playback continues to use the recorded centreline and grade.

Regional wildlife moves on tested verges, outside the race line. Meadow Run, Moorland Mire and Coastal Cliffs have hares. Sandstone Canyon and Slate Gorge have lizards. Autumn Ridge has squirrels, Pinewood Deluge and Twilight Taiga have foxes, Harbour Lanes has crabs, Alpine Pass has chamois, and Frozen Lakes has snow hares. Each route has several sightings and animates one animal at a time near the car.

The 11 stage cards now use actual in-game viewpoints. The compositions include Meadow's hay rows, Harbour's waterfront, the Alpine lift, the Frozen Lakes camp, the Taiga lantern approach and Gorge's truss. Most show their Sprint route. Autumn Ridge shows the new tunnel in Classic. The contact shadow under each car now follows its footprint and the ground beneath the tyres. It softens as the car lifts away from the ground. The brake samples each connected controller's current trigger and X button, with separate engage and release thresholds around the trigger's rest position.

### Next tests and designs

1. **Controller release on Android.** Record the Godot axis value while pressing and releasing the trigger, after a pause and on reconnect. Compare one USB-C and one Bluetooth pad at the same stage start. After each release, hold full throttle and compare the next one second of speed against touch. Preserve partial braking and low-speed reverse.
2. **Readability through a tunnel.** Drive the first Alpine portal in both chase modes and the cockpit. Check whether the wall stripes give enough warning before the left edge enters the view. Try the same entrance at dusk. Test an interior lamp rhythm with fewer, brighter pools if drivers struggle to spot the bend.
3. **A true stacked road crossing.** Prototype a road that passes beneath its own bridge and drives across the same footprint later. Model the two road heights separately and keep projection, collisions, camera, pace notes and ghost playback on the correct road segment. Exercise resets and overtaking from both decks before authoring a full stage around it.
4. **Shadow calibration.** Compare a narrow deck, a steep bank, wet tarmac and a slow jump in the same light. Check tyre contact from low chase and roof clearance from photo mode. Measure the shadow update and wet-stage GPU frame times on a representative phone.
5. **Variant-specific previews.** Trial a second shot for locations with distinct Sprint and Classic features. Use the same camera aspect ratio as the menu and check whether a player can pick out the feature at thumbnail size.

## Implemented in 1.0.9

The handling comparison now samples four tyre positions at the race’s fixed tick. Each driven axle receives a share of the available engine torque. A tyre using grip to accelerate or brake has less available to turn. Braking transfers load forward, acceleration moves it rearward, and rear grip recovers progressively after releasing the handbrake. The open differential and bounded torque-bias model share the same force calculation. Roster AWD cars have class-specific torque splits. Suspension samples actual ground height under the wheels, with shorter travel on sealed stages and a more compliant setup on rough stages. The existing artistic gravity and jump cap still govern the airborne body.

| Stage | FWD launch | RWD launch | AWD launch | Powered corner heading change, FWD / RWD / AWD |
|---|---:|---:|---:|---|
| Meadow Run | 8.54 m/s | 12.42 m/s | 12.85 m/s | 17.8° / 21.2° / 19.8° |
| Frozen Lakes | 4.13 m/s | 4.73 m/s | 9.53 m/s | 16.8° / 22.0° / 18.7° |

Run `godot --headless res://tools/handling_baseline.tscn -- --trace=/tmp/rally.csv` to repeat the original equal-spec comparison and write the 1,512 fixed-tick input and force samples. The benchmark also checks split-grip torque bias, mirrored left/right response and loss of drive when unsupported. An automated impact-and-recovery drive using touch, a controller trigger and a digital controller button reached 14.19 m/s with each input.

On a Meadow jump approached at 12, 20 and 28 m/s, the car spent 32, 12 and 7 ticks respectively with only one axle supported. Both axles were unsupported for 0, 40 and 47 ticks. The sampled motion drives wheel travel, pitch and suspension thumps. The model uses a sprung body with limited travel. Individual wheel rotational inertia and independent unsprung masses remain potential extensions.

Regional additions include a haul track and scree fan in the rocky regions, asymmetric snow deposits and scouring in the snowy regions, ruts at forestry and moorland sites, longer hay and vine rows, and a longer Taiga lantern approach. An approach sightline is reserved for an Alpine lift tower. Roadside photo framing accounts for intervening ground. Mud has paired ruts, and touching a loose verge on one side can throw debris only from those wheels. The Lynx and Fennec now have different rear-window slopes, lamp profiles and tailgate pressings.

AI speed planning and medal calculations use available traction when estimating braking and acceleration. Existing ghost files record positions and headings, so playback needs no input re-simulation. On-phone rain performance, physical USB-C/Bluetooth feel and blind player recognition of locations still need device and player testing. The following sections retain the original 1.0.8 investigation for comparison.

## Original handling comparison · 1.0.8

The first handling prototype should address how a driven axle spends its available grip. In a controlled launch the same car hit exactly the same speed to two decimal places with front-, rear- and all-wheel drive. The layouts already feel distinct when turning under power. Preserving that distinction while making wheelspin and recovery depend on which tyres have grip offers more value than increasing the power of every AWD car.

The comparison uses the Ventura 60 with identical power, tyres, mass settings and gearing. Only its drive field changes. From the stage start, hold full throttle for 1.50 seconds. For the separate corner trial, start at 14 m/s, apply 45% steering and full throttle for 0.60 seconds. Both run at the race’s fixed 120 Hz. Yaw is heading change and peak slip is the game's dimensionless lateral-slip measure. Neither is an instrumented tyre measurement. Reproduce from the project root with `godot --headless res://tools/handling_baseline.tscn`.

| Sprint | Layout | Launch speed (m/s) | Corner exit (m/s) | Yaw (degrees) | Peak slip |
|---|---|---:|---:|---:|---:|
| Meadow Run | FWD | 13.97 | 18.11 | 17.9 | 0.000 |
| Meadow Run | RWD | 13.97 | 18.22 | 25.9 | 0.027 |
| Meadow Run | AWD | 13.97 | 18.19 | 20.3 | 0.000 |
| Frozen Lakes | FWD | 10.93 | 16.99 | 16.9 | 0.044 |
| Frozen Lakes | RWD | 10.93 | 16.58 | 24.5 | 0.172 |
| Frozen Lakes | AWD | 10.93 | 16.89 | 19.2 | 0.078 |

RWD turned eight degrees further than FWD in the Meadow trial. On Frozen Lakes it developed roughly four times the peak slip of FWD. The current code explicitly reduces FWD steering above half throttle and increases RWD yaw above 60% throttle and 6 m/s. Lateral friction also changes by layout. Longitudinal drive lacks an equivalent front/rear traction calculation. The results cover two short manoeuvres in one equal-spec car. Actual roster cars also differ in their performance ratings.

## Drivetrain and suspension priorities

| Order | Proposed change | Player-facing result and acceptance drive |
|---|---|---|
| 1 | Record front/rear surface, drive request, brake request, normal load, delivered force and slip at each fixed tick. Record the normalised controller or touch input alongside them. | Compare full-trigger and touch launches with the same starting state, including after a barrier impact. Holding the same effective input should produce the same speed trace. Preserve partial-trigger control. |
| 2 | Split the car into front and rear tyre contacts. Limit each axle’s combined braking, acceleration and cornering demands to its available grip. Send engine force only to driven axles. | On a low-grip launch AWD should exploit both axles when the engine can exceed a single axle’s traction limit. On a power-limited straight, identical gearing and engine output should permit similar speeds. |
| 3 | Move axle load forward when braking and rearward when accelerating. Start with longitudinal load transfer proportional to mass × acceleration × centre-of-mass height / wheelbase. Keep both axle loads nonnegative. | Compare a downhill braked hairpin and an uphill exit in the same FWD and RWD car. Look for progressive front push on FWD power and recoverable rear slip on RWD power. |
| 4 | Sample each wheel’s surface at patch edges and verges. Begin with one normal load per axle split across its two wheels. | Clip the icy patch with just the left wheels, then repeat on the right. The low-grip side and its tyre effects should swap sides. |
| 5 | Add front/rear torque split for AWD and a bounded model of differential locking. Evaluate an open axle before adding limited-slip variants. | Start with one driven wheel on ice. An open differential should limit the torque available at both wheel ends. A locking variant should improve departure and change corner rotation. Keep torque conserved. |
| 6 | Apply service-brake bias and handbrake at the relevant axles. Allow rear grip to return progressively on handbrake release. | At a repeatable hairpin entry speed a short pull should rotate the rear. A sustained pull should scrub speed. Countersteer and release should give the player a recovery window. |
| 7 | Connect wheel torque to gear ratio and an engine torque curve, including closed-throttle engine braking. | A low-gear exit should be easier to spin up on loose ground than a higher-gear exit. Check shift continuity, reverse, automatic shifts and shift lamps. |
| 8 | Sample front and rear road elevation separately. Drive body heave and pitch from spring compression and damping at the fixed step. | Drive the same hump at three speeds. The leading axle should unload and regain support first. A landed axle should contribute grip while the other is airborne. |
| 9 | Add rebound/compression damping, travel limits and progressive bump stops. Compare a compliant gravel setup with a shorter tarmac setup on the same car. | A single bump should settle without repeated oscillation. Corrugations should not permanently pack down the suspension. Photograph full droop and bottoming from the side. |
| 10 | Derive visual body roll, tyre debris and the sound of suspension compression from contact and load. Interpolate the visual pose between physics ticks. | A one-wheel verge strike should eject debris on that side. A two-wheel landing should sound and look different from a gentle compression, without moving the cockpit horizon abruptly. |
| 11 | Re-run medal targets and AI after handling stabilises. Version physics-dependent ghost data where re-simulation is needed. | Compare valid old saves, ghost playback, repeatable finish times and AI bridge clearance. Measure fixed-step CPU time on a representative Android phone before expanding to four independent suspension corners. |

The 1.0.8 build used an artistic gravity of 22 game units/s², caps crest launch velocity at 4.2, adds up to 0.025 m of off-road wheel jiggle and shows 0.09 m of wheel droop while airborne. Landing excites a visual spring on the body. Start suspension work by measuring contact and pitch on a known hump. Changing global gravity first would also change jumps and landing timing on every existing route.

The axle proposal uses combined-slip tyre modelling as a reference. The half-car suspension example is a useful intermediate model because it represents sprung-mass bounce and pitch with front and rear springs and dampers. Rally de España drivers also describe the practical impact of the gravel-to-tarmac setup change. The suggested tuning values and acceptance drives above are development proposals for Paper Rally. [MathWorks vehicle dynamics reference](https://www.mathworks.com/help/pdf_doc/vdynblks/vdynblks_ref.pdf) · [MathWorks automotive suspension](https://www.mathworks.com/help/simulink/slref/automotive-suspension.html) · [Four-wheel drive and differentials](https://www.howacarworks.com/advanced-driving/using-four-wheel-drive) · [FIA driver discussion](https://www.fia.com/news/2013-rally-de-espana-post-event-press-conference-0)

## Four rally games, four decisions in this build

| Reference | Change to Paper Rally | Next review |
|---|---|---|
| art of rally | Landmark siting considers the approaching driver. Sightlines from approach and departure points influence placement of tall props. All 19 cars were rendered from the rear in the same neutral livery. | Sandhopper’s exposed wheels and crossed braces read immediately. Tempest’s wing and Mule’s tall pickup body also survive the neutral-paint test. Lynx Turbo and Fennec R2 share a roof outline and similar rear lamp spacing. Prioritise their C-pillar angle, tailgate pressing and lamp height before adding more fasteners. |
| Pocket Rally | Photo mode offers a second, roadside camera within 70 m of a regional landmark. The driver can frame the car passing the site and return to the previous orbit. | At Harbour Lanes, inspect the quay from both travel directions. On steep sites check for terrain between the eye and car. Consider individually authored spectator positions where a general view loses the landmark. |
| Rush Rally 3 | Tyre marks widen with slip, the front wheels create bow spray at a moving ford crossing, and a blow scuffs the panel locally according to its deformation. | Run a shallow ford at two speeds and stop in the water. Compare the front contact, drying trail and stationary surface across chase and photo cameras. |
| Rush Rally Origins | Printed surface patches follow the physical road interval and its bends. Ice gets broken pale strokes. Harbour captures compare high chase, low chase and the 58-degree cockpit. | Test ice recognition at speed in dusk and snow. Give visually confusing mud and tarmac transitions different edge or grain patterns while keeping the actual grip boundary legible. |

Reference observations use the developers’ public material. The camera, scenery and effects are original Paper Rally implementations. [art of rally](https://store.steampowered.com/app/550320/art_of_rally/) · [Pocket Rally](https://www.illusion-magic.com/pr) · [Rush Rally 3](https://store.steampowered.com/app/2020860/Rush_Rally_3/) · [Rush Rally Origins](https://store.steampowered.com/app/1728660/Rush_Rally_Origins/)

## Wider scenery and device review

- **Coastal Cliffs and Harbour Lanes.** Review roof, trunk and foundation footprints from above and below the coast. The placement test now samples the inner and outer footprint in eight directions. Look for level headlands that still support clusters and unsupported edges that stay bare. Inspect an actual rainy Android run at the same location as the green-band report, including several camera switches and a photo orbit.
- **Slate Gorge and Sandstone Canyon.** Use crossing parapets, a distant winding haul road and a dry drainage fan to give the driver scale across a ravine. Compare three unlabelled screenshots along each route before increasing prop density.
- **Frozen Lakes and Alpine Pass.** Try wind-scoured ice on the exposed side of a crest and piled snow on the sheltered side. Use a single chairlift tower as a sighting reference on approach. Check both high chase and cockpit sightlines before committing additional towers.
- **Pinewood Deluge and Moorland Mire.** Prototype a single-sided fan of wet gravel and a darker wheel rut at one logging turnout. Compare frame time with the current stage during heavy rain, particularly with spray close to the lens.
- **Meadow Run, Autumn Ridge and Twilight Taiga.** Build one recognisable approach per route with a repeated regional feature, such as cut hay rows, hillside trellises or a sequence of lakeshore lamps. Ask a tester to identify the location from a five-second approach without labels.
- **Car review.** Repeat the neutral comparison from a front three-quarter angle and the normal moving chase camera. Test recognition at phone size before altering proportions. Compare impact damage at matched contact speeds and angles to verify that the struck wheel arch, lamp and adjacent panel tell the same story.
