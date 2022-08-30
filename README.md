# NIST STEP File Analyzer and Viewer

With these instructions you can build the [NIST STEP File Analyzer and Viewer](https://www.nist.gov/services-resources/software/step-file-analyzer-and-viewer) (SFA) from the source code.  SFA generates a spreadsheet and visualization from an ISO 10303 Part 21 STEP file.  More information, sample spreadsheets and visualizations, and documentation about SFA is available on the website including the [STEP File Analyzer and Viewer User Guide](https://www.nist.gov/publications/step-file-analyzer-and-viewer-user-guide-update-7).

The [NIST STEP to X3D Translator](https://www.nist.gov/services-resources/software/step-x3d-translator) is used by the SFA Viewer to convert STEP b-rep part geometry to X3D and has its own source code and executable.

## Prerequisites

The STEP File Analyzer and Viewer can only be built and run on Windows computers.  This is due to a dependence on the IFCsvr toolkit that is used to read and parse STEP files.  IFCsvr only runs on Windows.

Microsoft Excel is required to generate spreadsheets.  CSV (comma-separated values) files will be generated if Excel is not installed.  

**You must first install and run the NIST version of the STEP File Analyzer and Viewer before running your own version.**

- Go to the [STEP File Analyzer and Viewer](https://www.nist.gov/services-resources/software/step-file-analyzer-and-viewer) to download the software
- Extract STEP-File-Analyzer.exe from the zip file and run it.  This will install the IFCsvr toolkit that is used to read STEP files.  The toolkit only runs on Windows.

Download the SFA files from the GitHub 'source' directory to a directory on your computer.

- The name of the directory is not important
- The STEP File Analyzer and Viewer is written in [Tcl](https://wiki.tcl-lang.org/)
- Some of the Tcl code is based on [CAWT](http://www.cawt.tcl3d.org/)

freeWrap wraps the SFA Tcl code to create an executable.

- Download freewrap651.zip from <https://sourceforge.net/projects/freewrap/files/freewrap/freeWrap%206.51/>.  More recent versions of freeWrap will **not** work with wrapping SFA.
- Extract freewrap.exe and put it in the same directory as the SFA files that were downloaded from the 'source' directory.

Several Tcl packages not included in freeWrap also need to be installed.

- teapot.zip in the 'source' directory contains the additional Tcl packages
- Create a directory C:/Tcl/lib
- Unzip teapot.zip to the 'lib' directory to create C:/Tcl/lib/teapot

## Build the STEP File Analyzer and Viewer

Open a command prompt window and change to the directory with the SFA Tcl files and freewrap.  To create the executable sfa.exe, enter the command:

```
freewrap -f sfa-files.txt
```

## Differences from the NIST-built version of STEP File Analyzer and Viewer

Some features are not available in the user-built version including: tooltips, unzipping compressed STEP files, automated PMI checking for the [NIST CAD models](<https://www.nist.gov/el/systems-integration-division-73400/mbe-pmi-validation-and-conformance-testing>), and inserting images of the NIST test cases in the spreadsheets.  Some of the features are restored if the NIST-built version is run first.

## Disclaimers

[NIST Disclaimer](https://www.nist.gov/disclaimer)
