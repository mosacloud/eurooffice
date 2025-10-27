# 2025 09 30 Meeting notes

These are some notes I wrote down in the meeting we had.

- x2t is a webassembly build that let's you convert from a fileformat to another fileformat.
- The internal OnlyOffice format (which you cannot save into a file) is very similar to the Microsoft Office format.
- Drop-in branding
- It uses v8 (in c) but they don't need that part.
- LibreOffice/OpenOffice import to Internal OnlyOffice format is worse than converting it first to Microsoft Office and then importing it to Internal OnlyOffice format.
- "My document is corrupted." OnlyOffice admins might need sometimes to revert patches to documents. Not everyone experiences the same though.
- So we need to have a `build.sh` that could have an argument as: desktop or server so that we can build that fragment/part of OnlyOffice. In addition to that it should have a second argument to specify: brand1, brand2 or brand3.
- The code for App mobile support is no longer there. It was in v5, v6.
- Mobile Web version is probably present with bTactic current patches.

---

One plan might be:

- Fork everything
- Apply unlimited changes from bTactic
- Fork
- Customization on the same codebase
- Explore customization in one place as one vendor suggests. ?That way the OnlyOffice name change can be in done in Realtime?

---

- Regarding the bTactic Deb package is 98% equivalent to theirs because you somehow need to install their package first before installing the bTactic one.

---

Notes about the Enterprise edition:

- They use a different build system
- They have Mobile Web version enabled.
- They have App Mobile support enabled.
- They support many more users than a single FOSS OnlyOffice instance. They probably use a clustering system using rabbitmq.
- There must be a Kubernet Deployment with code that probably does not exist in Open Source.
