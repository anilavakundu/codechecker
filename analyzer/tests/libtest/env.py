# -------------------------------------------------------------------------
#
#  Part of the CodeChecker project, under the Apache License v2.0 with
#  LLVM Exceptions. See LICENSE for license information.
#  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# -------------------------------------------------------------------------
"""
Test environment setup and configuration helpers.
"""


import json
import os
import tempfile

from functional import PKG_ROOT
from functional import REPO_ROOT


def codechecker_env():
    checker_env = os.environ.copy()
    cc_bin = os.path.join(PKG_ROOT, 'bin')
    checker_env['PATH'] = cc_bin + ":" + checker_env['PATH']
    return checker_env


def test_proj_root():
    return os.path.abspath(os.environ['TEST_PROJ'])


def codechecker_cmd():
    return os.path.join(PKG_ROOT, 'bin', 'CodeChecker')


def tu_collector_cmd():
    return os.path.join(PKG_ROOT, 'bin', 'tu_collector')


def get_workspace(test_id='test'):
    """ return a temporary workspace for the tests """
    workspace_root = os.environ.get("CC_TEST_WORKSPACE_ROOT")
    if not workspace_root:
        # if no external workspace is set create under the build dir
        workspace_root = os.path.join(REPO_ROOT, 'build', 'workspace')

    if not os.path.exists(workspace_root):
        os.makedirs(workspace_root)

    if test_id:
        return tempfile.mkdtemp(prefix=test_id+"-", dir=workspace_root)
    else:
        return workspace_root


def test_env(test_workspace):
    base_env = os.environ.copy()
    base_env['PATH'] = os.path.join(PKG_ROOT, 'bin') + \
        ':' + base_env['PATH']
    base_env['HOME'] = test_workspace
    return base_env


def import_test_cfg(workspace):
    cfg_file = os.path.join(workspace, "test_config.json")
    test_cfg = {}
    with open(cfg_file, 'r', encoding="utf-8", errors="ignore") as cfg:
        test_cfg = json.loads(cfg.read())
    return test_cfg


def export_test_cfg(workspace, test_cfg):
    cfg_file = os.path.join(workspace, "test_config.json")
    with open(cfg_file, 'w', encoding="utf-8", errors="ignore") as cfg:
        cfg.write(json.dumps(test_cfg, sort_keys=True, indent=2))


def setup_test_proj_cfg(workspace):
    return import_test_cfg(workspace)['test_project']
