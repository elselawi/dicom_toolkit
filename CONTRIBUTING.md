# Contributing to dicom_toolkit

Thank you for your interest in contributing to dicom_toolkit.

dicom_toolkit is an open-source project built for the community. This document
explains how to contribute and clearly describes the licensing and ownership
model so everyone understands how the project is used and sustained.

Please read this document carefully before contributing.

---

## Project Philosophy (Please Read First)

dicom_toolkit is:

- Fully open-source
- Free for individuals, researchers, students, and the community
- Publicly available with no hidden or restricted features

The goal of this project is **not** to take community work and sell it.
The goal is to keep the project open while allowing companies to support
its development through commercial licensing when needed.

---

## License Overview

dicom_toolkit is released under the **GNU General Public License (GPL)**.

This means:

- Anyone can use the project for free
- Anyone can study, modify, and redistribute it
- Any public redistribution must follow GPL terms

The open-source version is the **complete project**, not a limited edition.

---

## Commercial Use (Companies Only)

Companies or enterprises may need a **commercial license** in cases such as:

- Using dicom_toolkit inside proprietary or closed-source products
- Using dicom_toolkit in paid SaaS platforms without GPL compliance
- Internal corporate usage where GPL obligations are legally incompatible

In these cases:

- The company pays for a commercial license
- The community version remains free and open
- No features are removed from the open-source project

Individuals and non-commercial users **do not need to pay**.

---

## Contributor License Agreement (CLA)

This project uses a **Contributor License Agreement (CLA)**.

By submitting a contribution, you confirm that:

- Your work will remain part of the open-source project under GPL
- The Project Owner may also offer commercial licenses to companies
- You are not giving up community access to your work
- You are not entitled to payment or revenue sharing

The CLA exists only to:

- Protect the project legally
- Allow sustainable development
- Avoid future licensing conflicts

for more information, see [Contributor License Agreement (CLA)](CLA.md).

---

## How to Contribute

### Reporting Bugs

Before opening a new issue, please check existing issues:
https://github.com/elselawi/dicom_toolkit/issues

When reporting a bug, include:

- A clear title
- Steps to reproduce
- Expected and actual behavior
- Logs or minimal examples if possible

---

### Suggesting Enhancements

Enhancements are welcome.

Please open an issue explaining:

- What you want to improve
- Why it is useful
- How it aligns with the project goals

---

### Pull Requests

To submit a pull request:

1. Fork the repository
2. Create a branch from `main`
3. Write clean and readable code
4. Add or update tests if needed
5. Run the following before submitting:

   ```bash
   dart test
   dart analyze
   dart format .
   ```