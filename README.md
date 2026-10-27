# EUM Mid Term Examination

Professional **1920×1080 Mid Term Examination Date-Sheet Display** for **Emerson University Multan**, designed for Raspberry Pi and info-beamer.

## Source

Official **CSET Mid Term Examination Fall 2026** date sheet for the **Faculty of Computing & Emerging Technologies**, effective **07 September 2026**.

## Examination Period

**28 October 2026 – 06 November 2026**

## Automatic Behavior

- Displays the current **Pakistan Standard Time (PKT / UTC+5)** date and time.
- Automatically rotates through examination sections.
- Highlights the **NOW • CURRENT EXAM** when an examination is in progress.
- Displays the **NEXT • UPCOMING EXAM**.
- Shows examination date, time, course code, complete course title, room, and invigilator.
- Automatically determines the current and next examination using the system time.
- Continues to operate offline because examination data is bundled in `exam.json`.
- Uses the official **Emerson University Multan logo** with a transparent background.
- Designed specifically for **1920×1080 Full HD displays**.
- Optimized for Raspberry Pi / info-beamer deployment.

## Data

The supplied official examination date-sheet PDF was converted into `exam.json`.

The bundled data contains the examination schedule required for the Faculty of Computing & Emerging Technologies.

## Package Files

```text
EUM-Mid-Term-Examination/
├── exam.json
├── node.lua
├── node.json
├── package.json
├── package.png
├── logo.png
├── font.ttf
├── font-bold.ttf
└── README.md
```

## Display Features

### Current Examination

The display automatically identifies an examination that is currently in progress and highlights it in the **NOW • CURRENT EXAM** panel.

### Upcoming Examination

The **NEXT • UPCOMING EXAM** panel automatically shows the next examination after the current time.

### Pakistan Standard Time

The display uses **PKT (UTC+5)** for examination date and time calculations to ensure consistent operation on the Raspberry Pi.

## Institution

**Emerson University Multan**  
**Faculty of Computing & Emerging Technologies**

## Examination

**Mid Term Examination – Fall 2026**

**Examination Dates:** 28 October 2026 – 06 November 2026

## Resolution

**1920 × 1080 Full HD**

## Platform

**Raspberry Pi / info-beamer**

## Offline Support

The package is designed to work without an Internet connection. All examination schedule data is bundled locally in `exam.json`.

## Updating the Date Sheet

When an official revised examination date sheet is issued:

1. Update `exam.json`.
2. Keep the existing display structure and formatting.
3. Update the package version in `package.json`.
4. Commit and publish the updated package.
5. Update the info-beamer package on the assigned device.

---

**Emerson University Multan**  
**Faculty of Computing & Emerging Technologies**  
**Powered by IT Center**
