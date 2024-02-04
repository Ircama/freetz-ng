#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
AVM Recovery Tool Log Analyzer
"""

import logging
import os
import yaml
from pathlib import Path
import re
from pprint import pformat

def sizeof_fmt(num, suffix="B"):
    for unit in ("", "K", "M", "G", "T", "P", "E", "Z"):
        if abs(num) < 1024.0:
            return f"{num:3.1f} {unit}{suffix}"
        num /= 1024.0
    return f"{num:.1f}Yi{suffix}"

def extract_key(list_lines, key, single=True, split=r'\s+'):
    pattern = ".*" + key + ".*"
    matching = [s for s in list_lines if re.findall(pattern, s)]
    if not matching:
        #logging.error("Error: missing %s", key)
        return None
    if single and len(matching) != 1:
        logging.error("Error: more than one '%s'", key)
        return None
    key_value = []
    for i in matching:
        try:
            msg_no_date = re.split('^[0-9]+:[0-9]+:[0-9]+: ', i)[1]
            key_value.append(re.split(split, msg_no_date))
        except Exception as e:
            logging.error("Error: invalid '%s': %s", key, e)
            return None
    return key_value

def avm_log_analizer(list_lines, debug=False):
    avm = {}
    avm["recover_fw_id"] = extract_key(list_lines, "recover-firmware-id")[0][1]
    avm["recover_fw_version"] = extract_key(
        list_lines, "recover-firmware-version"
    )[0][1]
    avm["avm_eva_version"] = extract_key(
        list_lines, "recv: 215 AVM EVA", single=False
    )[0][2:]
    avm["oem"] = extract_key(list_lines, "oem")[0][2]
    avm["provider"] = extract_key(list_lines, "provider")[0][2]
    avm["mtdnand"] = extract_key(
        list_lines, "set defaultsettings mtdnand", split=r"[\s():]+"
    )[0][4]
    avm["memsize"] = extract_key(list_lines, "send: SETENV memsize")[0][3]
    avm["mtdram1_start"] = extract_key(
        list_lines, "send: SETENV kernel_args_tmp mtdram1=", split=r"[\s,=]+"
    )[0][4]
    avm["mtdram1_end"] = extract_key(
        list_lines, "send: SETENV kernel_args_tmp mtdram1=", split=r"[\s,=]+"
    )[0][5]
    avm["ramload_start"] = extract_key(list_lines, "RAM-Load Image to ")[0][3]
    avm["ramload_end"] = extract_key(list_lines, "RAM-Load Image to ")[0][5]
    avm["stor_start"] = extract_key(list_lines, "send: STOR 0x")[0][2]
    avm["stor_end"] = extract_key(list_lines, "send: STOR 0x")[0][3]
    avm["filesize"] = extract_key(
        list_lines, "send image \(size=[0-9]+\) for mtd1", split=r"[\s()=]+"
    )[0][3]
    avm["gitbuild_ver"] = extract_key(
        list_lines, "gitbuild", split=r"[\s:]+"
    )[0][0]
    avm["gitbuild_build"] = extract_key(
        list_lines, "gitbuild", split=r"[\s:]+"
    )[0][2]
    avm["use_env"] = extract_key(
        list_lines,
        "environment successfully read",
        single=False,
        split=r"[\s()]+",
    )[0][3]
    avm["use_read_count"] = extract_key(list_lines, "send: RETR count")[0][2]
    avm["use_adam2_user"] = extract_key(
        list_lines, ": send: USER adam2", single=False
    )[0][2]
    avm["use_adam2_pwd"] = extract_key(
        list_lines, ": send: PASS adam2", single=False
    )[0][2]
    avm["use_sdram"] = extract_key(
        list_lines, "send: MEDIA SDRAM", single=False
    )
    avm["use_bye"] = extract_key(list_lines, "send: BYE", single=False)
    avm["use_reboot"] = extract_key(list_lines, "send: REBOOT", single=False)
    avm["use_getenv"] = extract_key(list_lines, "send: GETENV ", single=False)
    avm["use_setenv"] = extract_key(
        list_lines,
        "send: SETENV ",
        single=False,
        split=r"[\s=,]+",
    )
    avm["use_writeimage"] = extract_key(
        list_lines,
        "write image",
        single=False,
        split=r"[\s()/=]+",
    )
    
    if debug:
        logging.debug("Dump extracted values:\n%s", pformat(avm))
        print("\nEntering debug mode. Insert c to continue.")
        import pdb; pdb.set_trace()
    return avm

def compute_print_values(avm, debug=False):    
    ALIBYTES = 0
    adjustment = 24576  # 0x6000

    if not avm.get("use_sdram"):
        logging.error(
            "\nSDRAM is not used.\n"
            "This program can only compute values in SDRAM mode.\n"
        )
        return

    MAPLIMIT = int(avm.get("stor_end", "-1"), 16)
    MTDSTART = int(avm.get("stor_start", "-1"), 16)
    FREESIZE = int(avm.get("memsize", "-1"), 16)
    FILESIZE = int(avm.get("filesize", "-1"))
    adjusted_filesize = FILESIZE + 24576

    logging.warning(
        "\nExtracted values:\n"
        "MAPLIMIT = 0x%08X = %s [%s]\n"
        "MTDSTART = 0x%08X = %s [%s]\n"
        "FREESIZE = 0x%08X = %s [%s]\n"
        "FILESIZE = 0x%08X = %s [%s]\n",
        MAPLIMIT, MAPLIMIT, sizeof_fmt(MAPLIMIT),
        MTDSTART, MTDSTART, sizeof_fmt(MTDSTART),
        FREESIZE, FREESIZE, sizeof_fmt(FREESIZE),
        FILESIZE, FILESIZE, sizeof_fmt(FILESIZE)
    )

    FULLSIZE = FREESIZE + adjusted_filesize + ALIBYTES
    MAPSTART = MTDSTART + adjusted_filesize + ALIBYTES - FULLSIZE

    logging.warning(
        "\nComputed values:\n"
        "filesize = 0x%08X = %s [%s] (adjusted)\n"
        "MAPLIMIT = 0x%08X = %s [%s]\n\n"
        "FULLSIZE = 0x%08X = %s [%s]\n"
        "MAPSTART = 0x%08X = %s [%s]\n",
        adjusted_filesize, adjusted_filesize, sizeof_fmt(adjusted_filesize),
        MAPLIMIT, MAPLIMIT, sizeof_fmt(MAPLIMIT),
        FULLSIZE, FULLSIZE, sizeof_fmt(FULLSIZE),
        MAPSTART, MAPSTART, sizeof_fmt(MAPSTART)
    )

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        epilog='AVM Recovery Tool Log Analyzer'
    )

    parser.add_argument(
        dest='log_pathname',
        type=argparse.FileType('r'),
        help="Log file pathname",
        default=0,
        metavar='CONFIG_FILE'
    )
    parser.add_argument(
        '-d',
        '--debug',
        dest='debug',
        action='store_true',
        help='Print debug information'
    )
    args = parser.parse_args()

    logging_level = logging.WARNING
    logging_fmt = "%(message)s"
    env_key=os.path.basename(Path(__file__).stem).upper() + '_LOG_CFG'
    path = Path(__file__).stem + '-log.yaml'
    value = os.getenv(env_key, None)
    if value:
        path = value
    if os.path.exists(path):
        with open(path, 'rt') as f:
            config = yaml.safe_load(f.read())
        try:
            logging.config.dictConfig(config)
        except Exception as e:
            logging.basicConfig(level=logging_level, format=logging_fmt)
            logging.critical("Cannot configure logs: %s. %s", e, path)
    else:
        logging.basicConfig(level=logging_level, format=logging_fmt)

    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    if args.debug:
        logging.debug("Reading log file %s", args.log_pathname.name)
    avm = avm_log_analizer(args.log_pathname.readlines(), debug=args.debug)
    compute_print_values(avm, debug=args.debug)
