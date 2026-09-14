![Sentry Aim Retention](assets/banner.png)

# Sentry Aim Retention

Aims to keep autonomous sentries facing their last tracked target after losing it, instead of turning back toward the Helldiver while their burst may still be firing.

- **Hold through target loss.** Retains the last sampled aim and pauses rotation as soon as the previous target disappears, without waiting for the firing state to finish.
- **Resume tracking and scanning.** Releases the hold when a replacement target appears or a scanning transition is detected.
- **Pause broad firing sweeps.** Gatling and machine-gun sentries can keep firing through small adjustments and nearby target changes, but pause shots during broad or prolonged turns and resume near the target. Their trigger and spin-up timer stay intact during the pause.

Aim retention applies to locally controlled Gatling, machine gun, laser cannon, rocket, flamethrower, mortar and EMS mortar sentries. Selective firing pauses apply to Gatling and machine-gun sentries.
