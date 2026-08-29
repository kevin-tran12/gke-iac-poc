# Layer 10: recovery profile

After the cluster root is re-applied with the Backup for GKE agent enabled, this
root creates an active but unscheduled, short-retention backup plan for the isolated `recovery`
namespace and a restore plan that restores Persistent Disk data. The gate creates
one backup and restore explicitly, asserts the exact proof file, deletes those
operations, and the teardown removes both plans afterward.
