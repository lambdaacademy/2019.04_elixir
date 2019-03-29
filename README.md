# RabbitmqWorkshopEx

## Repo structure

* master holds the end solution
* each step/excersie has its own branch
  * the branches are named with `step/{ORIDINAL}-{EXERCISE-SHORT-DESC}`, e.g. (`step/0-connect-to-rabbit`)
  * the beginning of a branch is tagged with `step-{ORIDINAL}-start`, e.g. (`step-0-start)` so that it's easy
    to see a diff that completion of a particular step brings
  * HEAD of a branch contains the final state for the step
  * if a "step branch" changes, it is merged to master and the the master has to be merged to all the subsequent
    "step branches"
* README holds instructions to the correspondins steps
