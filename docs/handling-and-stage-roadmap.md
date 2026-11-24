# Paper Rally handling and stage review · 1.0.8

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

## What a driver can feel today

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

Today the game uses an artistic gravity of 22 game units/s², caps crest launch velocity at 4.2, adds up to 0.025 m of off-road wheel jiggle and shows 0.09 m of wheel droop while airborne. Landing excites a visual spring on the body. Start suspension work by measuring contact and pitch on a known hump. Changing global gravity first would also change jumps and landing timing on every existing route.

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
