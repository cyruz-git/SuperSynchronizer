# SuperSynchronizer

**PLEASE NOTE THAT THIS IS BETA SOFTWARE. I'M IN NO WAY RESPONSIBLE FOR ANY DATA LOSS.**

*SuperSynchronizer* is an [AutoHotkey](http://ahkscript.org/) script that can be used for incremental and mirror directory synchronization. To use it only the AutoHotkey interpreter is required (**Unicode** version, 32 or 64 bit).

### How it works

The script is structured in to stages:

1. **REPLICATION CHECK**

    The files on the DESTINATION SIDE are synchronized with the files on the SOURCE SIDE.

2. **REVERSE CHECK**

    The files on the DESTINATION SIDE that don't exist on SOURCE SIDE are deleted.

The script can be instantiated multiple times, and the GUI will stack automatically starting from the TOP-RIGHT corner. A detailed log file is createad by default in *A_ScriptDir* (the script directory).

### Files

Name | Description
-----|------------
COPYING | GNU General Public License.
README.md | This document.
SuperSynchronizer.ahk | Main and only script file.

### How to use

To use *SuperSynchronizer* the **[ VARIABLES SECTION ]** of the script must be edited to comply with the desired configuration.

The following table explain the meaning of all the present variables:

Name | Description | Example
-----|-------------|--------
SOURCE_DIR | Source directory (absolute path, without quotes). | `C:\Source\Folder`
DESTIN_DIR | Destination directory (absolute path, without quotes). | `C:\Destination\Folder`
MIRRORING | Enable mirroring, deleting files on destination that are not present on source (1 to enable, 0 to disable).| `1` or `0`
SIMULATION | Enable simulation, forcing logging to store all operations that will be discarded (1 to enable, 0 to disable). | `1` or `0`
LOG_ENABLE | Enable logging, storing all operations history on file (1 to enable, 0 to disable) | `1` or `0`
LOG_FILE | Log file path (absolute path, without quotes). Default to *Scriptname*.**log** in the script directory. Will be created with a numerical suffix if other log files with the same name are present. | `C:\LogDir\MySync.log`
INTERACTIVE | Enable the interactive mode showing a GUI in the TOP-RIGHT corner that allows to stop the script (1 to enable, 0 to disable). | `1` or `0`
LOW_PRIORITY | Enable the low priority mode for the script process (1 to enable, 0 to disable). | `1` or `0`
EX_REPLICATION_DIRS | Replication check directories exclusions. These directories will not be copied on destination (newline separated, without quotes, enclosed by <>, either the full path or a generic directory name). | `<C:\Some\Dir>`<br>`<GenericDirName>`<br>`<AnotherDir>`
EX_REPLICATION_FILES | Replication check files exclusions. These files will not be copied on destination (newline separated, without quotes, enclosed by <>, either the full path or a generic file name). | `<C:\Path\To\A\File>`<br>`<GenericFileName.ext>`<br>`<AnotherFile.ext>`
EX_REPLICATION_EXTS | Replication check extensions exclusions. The files with this extensions will not be copied on destination (newline separated, without quotes, enclosed by <>). | `<txt>`<br>`<log>`
EX_REVERSE_DIRS | Reverse check directories exclusions. These directories will not be deleted on destination (newline separated, without quotes, enclosed by <>, either the full path or a generic directory name). | `<C:\Some\Dir>`<br>`<GenericDirName>`<br>`<AnotherDir>`
EX_REVERSE_FILES | Reverse check files exclusions. These files will not be deleted on destination (newline separated, without quotes, enclosed by <>, either the full path or a generic file name). | `<C:\Path\To\A\File>`<br>`<GenericFileName.ext>`<br>`<AnotherFile.ext>`
EX_REVERSE_EXTS | Reverse check extensions exclusions. The files with this extensions will not be deleted on destination (newline separated, without quotes, enclosed by <>). | `<txt>`<br>`<log>`

### License

*SuperSynchronizer* is released under the terms of the [GNU General Public License](http://www.gnu.org/licenses/).

### Contact

For hints, bug reports or anything else, you can contact me at [focabresm@gmail.com](mailto:focabresm@gmail.com), open a issue on the dedicated [GitHub repo](https://github.com/cyruz-git/SuperSynchronizer) or use the [AHKscript development thread](http://ahkscript.org/boards/viewtopic.php?f=6&t=1288).