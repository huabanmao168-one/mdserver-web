# coding:utf-8

import subprocess
import sys
import io
import os
import time
import re
import json

# print(sys.platform)
if sys.platform != "darwin":
    os.chdir("/www/server/mdserver-web")


web_dir = os.getcwd() + "/web"
if os.path.exists(web_dir):
    sys.path.append(web_dir)
    os.chdir(web_dir)

import core.mw as mw
import core.db as db

app_debug = False
if mw.isAppleSystem():
    app_debug = True


def getPluginName():
    return 'backup_ftp'


def getPluginDir():
    return mw.getPluginDir() + '/' + getPluginName()


sys.path.append(getPluginDir() + "/class")
from ftp_client import FtpPSClient


def getServerDir():
    return mw.getServerDir() + '/' + getPluginName()


def status():
    return 'start'


def getConf():
    cfg = getServerDir() + "/cfg.json"
    if not os.path.exists(cfg):
        rdata = {
            'use_sftp':False,
        }
        return mw.returnJson(False, "未配置", rdata)
    data = mw.readFile(cfg)
    data = json.loads(data)
    return mw.returnJson(True, "OK", data)


def setConf():
    args = mw.getPluginArgs()
    data = mw.checkPluginArgs(args, ['use_sftp', 'ftp_user',
                            'ftp_pass', 'ftp_host', 'backup_path'])
    if not data[0]:
        return data[1]

    cfg = getServerDir() + "/cfg.json"

    values = ['ftp_user',
              'ftp_pass',
              'ftp_host']
    for v in values:
        if args[v] == '':
            return mw.returnJson(False, '必填资料不能为空，请核实!', [])

    if args['backup_path'] == '':
        args['backup_path'] = "/backup"

    try:
        ftp = FtpPSClient(load_config=False)
        ftp.injection_config(args)
        data = ftp.getList("/")
        if data:
            mw.writeFile(cfg, mw.getJson(args))
            return mw.returnJson(True, '设置成功', [])
    except Exception as e:
        return mw.returnJson(False, "FTP校验失败，请核实!\n" + str(e), [])


def getList():
    cfg = getServerDir() + "/cfg.json"
    if not os.path.exists(cfg):
        return mw.returnJson(False, "未配置FTP,请点击`账户设置`", [])

    args = mw.getPluginArgs()
    data = mw.checkPluginArgs(args, ['path'])
    if not data[0]:
        return data[1]

    try:
        ftp = FtpPSClient()
        flist = ftp.getList(args['path'])
        return mw.returnJson(True, "ok", flist)
    except Exception as e:
        return mw.returnJson(False, str(e), [])


def createDir():
    cfg = getServerDir() + "/cfg.json"
    if not os.path.exists(cfg):
        return mw.returnJson(False, "未配置FTP,请点击`账户设置`", [])

    args = mw.getPluginArgs()
    data = mw.checkPluginArgs(args, ['path', 'name'])
    if not data[0]:
        return data[1]

    ftp = FtpPSClient()
    isok = ftp.createDir(args['path'], args['name'])
    if isok:
        return mw.returnJson(True, "创建成功")
    return mw.returnJson(False, "创建失败")


def deleteDir():
    args = mw.getPluginArgs()
    data = mw.checkPluginArgs(args, ['dir_name', 'path'])
    if not data[0]:
        return data[1]

    ftp = FtpPSClient()
    isok = ftp.deleteDir(args['path'], args['dir_name'])
    if isok:
        return mw.returnJson(True, "删除成功")
    return mw.returnJson(False, "删除失败")


def deleteFile():
    args = mw.getPluginArgs()
    data = mw.checkPluginArgs(args, ['path', 'filename'])
    if not data[0]:
        return data[1]

    ftp = FtpPSClient()
    isok = ftp.deleteFile(args['path'] + "/" + args['filename'])
    if isok:
        return mw.returnJson(True, "删除成功")
    return mw.returnJson(False, "删除失败")

def findArchives(directory, prefix):
    archives = {}
    if os.path.isdir(directory):
        with os.scandir(directory) as entries:
            for entry in entries:
                if entry.name.startswith(prefix) and entry.name.endswith('.gz') and entry.is_file():
                    stat = entry.stat()
                    archives[entry.path] = (stat.st_ino, stat.st_mtime_ns, stat.st_size)
    return archives


def backupAllFunc(stype):
    name, count = sys.argv[2:4]
    panel_dir = mw.getPanelDir()
    backup_dir = mw.getBackupDir()
    script = os.path.join(panel_dir, 'scripts', 'backup.py')
    backup_type = stype
    if stype == 'site':
        directory, prefix = os.path.join(backup_dir, 'site'), 'web_' + name + '_'
    elif stype == 'path':
        directory = os.path.join(backup_dir, 'path')
        prefix = 'path_' + os.path.basename(os.path.normpath(name)) + '_'
    elif stype == 'database' or stype.startswith('database_'):
        plugin = stype[len('database_'):] if stype != 'database' else 'mysql'
        if stype != 'database':
            script = os.path.join(panel_dir, 'plugins', plugin, 'scripts', 'backup.py')
        backup_type = 'database'
        directory = os.path.join(backup_dir, backup_type, plugin)
        prefix = 'db_' + (name[:-10] if name.endswith('@undefined') else name) + '_'
    else:
        return False

    arguments = [sys.executable, script, backup_type, name, count]
    if backup_type in ('site', 'path'):
        arguments.append(sys.argv[4] if len(sys.argv) > 4 else '')

    backups = findArchives(directory, prefix)
    if subprocess.run(arguments).returncode != 0:
        mw.echoInfo('本地备份失败，FTP 上传已取消。')
        return False
    new_archives = [filename for filename, stat in findArchives(directory, prefix).items()
                    if stat != backups.get(filename)]
    if not new_archives:
        mw.echoInfo('未找到本次任务生成的备份文件。')
        return False

    ftp = FtpPSClient()
    for filename in sorted(new_archives):
        mw.echoInfo('准备上传文件 {}'.format(filename))
        if not ftp.uploadFile(filename, backup_type):
            mw.echoInfo('FTP 上传失败：' + filename)
            return False

    mw.echoStart('开始删除远程备份')
    previous = sorted(backups.keys() - set(new_archives))
    expired = max(0, len(previous) + len(new_archives) - int(count))
    for filename in previous[:expired]:
        object_name = ftp.buildDirName(backup_type, os.path.basename(filename))
        if ftp.deleteFile(object_name):
            mw.echoInfo('已清理远程过期备份文件：' + object_name)
    mw.echoEnd('结束删除远程备份')
    return True


def in_array(name, arr=[]):
    for x in arr:
        if name == x:
            return True
    return False


def installPreInspection():
    return 'ok'

if __name__ == "__main__":
    func = sys.argv[1]
    if func == 'status':
        print(status())
    elif func == 'start':
        print(start())
    elif func == 'stop':
        print(stop())
    elif func == 'restart':
        print(restart())
    elif func == 'reload':
        print(reload())
    elif func == 'install_pre_inspection':
        print(installPreInspection())
    elif func == 'conf':
        print(getConf())
    elif func == 'set_config':
        print(setConf())
    elif func == "get_list":
        print(getList())
    elif func == "create_dir":
        print(createDir())
    elif func == "delete_dir":
        print(deleteDir())
    elif func == 'delete_file':
        print(deleteFile())
    elif in_array(func, ['site', 'database', 'path']) or func.find('database_') > -1:
        sys.exit(0 if backupAllFunc(func) else 1)
    else:
        print('error')
