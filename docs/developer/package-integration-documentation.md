# Big Bang Package: Documentation

Big Bang requires some additional documentation for supported packages to help user's understand how it interacts with other components.  The following are documents that should be created or updated for integration into Big Bang:

- Folder and Archtecture markdown document within [the BigBang charter](../../charter/packages/) which details it's requirements, dependencies and interaction with other components of BigBang.
- README.md in root of package based on [helm-docs go template from gluon](https://repo1.dso.mil/platform-one/big-bang/apps/library-charts/gluon/-/blob/master/docs/bb-package-readme.md)
- `docs/` folder within package, next to `chart` which detail implementation for customers to review.
  - Must start with an `overview.md` that describes what application does and what function it performs, along with link to BigBang Architecture.md doc.
  - If package has SSO support, a `keycloak.md` with information for fully configuring the Keycloak Client & the package.
  - `troubleshooting.md` document with common issues and steps to resolve them.
  - `backup.md` document with information about built in snapshots, or overview of using BigBang add-on Velero for backing up data within package.
