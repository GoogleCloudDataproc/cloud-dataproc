# Findings - 2026-03-12

**Topic:** Audit Script Coverage for Dataproc Script CUJs

**Discovery:**

Upon reviewing the `bin/` directory, the following audit script gaps were identified for the different cluster creation/destruction Critical User Journeys (CUJs):

*   **Missing:** `bin/audit-dpgce-create-custom-private`: Needed to validate the setup by `bin/create-dpgce-custom-private`.
*   **Missing:** `bin/audit-dpgke-create`: Needed to validate `bin/create-dpgke`.
*   **Missing:** `bin/audit-dpgke-destroy`: Needed to validate `bin/destroy-dpgke`.

**Implication:**

Without these audit scripts, we cannot automatically verify that the creation and destruction of custom-private DPGCE clusters and all DPGKE clusters are working as expected, potentially leading to manual errors and inconsistencies.

**Action:**

These missing audit scripts should be created to ensure full test coverage of the provisioning scripts.
