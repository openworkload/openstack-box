#!/usr/bin/env python3
#
# Copyright (c) 2016-2017 Sky Workflows. All Rights Reserved.
#
# This software is the confidential and proprietary information of
# Sky Workflows ("Confidential Information"). You shall not
# disclose such Confidential Information and shall use it only in
# accordance with the terms of the license agreement you entered into
# with Sky Workflows or its subsidiaries.

# vim: tabstop=4 expandtab shiftwidth=4 softtabstop=4

import json
import logging
import os

from subprocess import Popen, PIPE, STDOUT
from pyutils.jsoner import JsonManipulator


log = logging.getLogger("scheduler")


class SchedulerRunner:

    def __init__(self):
        self._my_dir = os.path.dirname(os.path.realpath(__file__))

    def run(self, json_map):
        json_manipulator = JsonManipulator()
        bin_in = json_manipulator.convert_to_bin(json_map)
        return self._run_scheduler(bin_in)

    def _run_scheduler(self, bin_in):
        log.debug("Run scheduler")
        bin_dir = os.path.join(self._my_dir, "..", "..", "..", "swm-sched", "bin")
        scheduler = os.path.join(bin_dir, "swm-sched")
        args = "%s -p %s -d" % (scheduler, bin_dir)
        cwd = os.path.join(self._my_dir, "..")
        p = Popen(args, cwd=cwd, shell=True, stdout=PIPE, stdin=PIPE)
        out = p.communicate(input=bin_in)[0]
        log.debug("Scheduler result: %s" % out)
        return out
