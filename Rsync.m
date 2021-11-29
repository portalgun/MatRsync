classdef Rsync < handle
properties
    remoteName
    srcDir
    destDir
    direction
    filesListFile % XXX

    mode
    bAsync
    bLog
    bWatch

    term

    configFile
    logFname
    defaultFlags
end
properties(Constant)
    termTitle='matwatch.Rsync'
    logfrmt='MR_%i_%s.log' %
    logRe  ='MR_[0-9]{10}_[A-Za-z.-]\.log'
    validModes={'a','db'}
end
methods(Static)
    function clearLogs()
        files=findLogFiles.Rsync();
        disp([Str.tabify(Cell.toStr(files))]);

        out=Input.yn('Really delete the above files?');
        if ~out
            return
        end
        for i = 1:length(files)
            delete(files{i});
        end
    end
    function out=getLogFname(remoteName)
        dire=getenv('LOG');
        if isempty(out)
            error('''LOG'' environment variable not set');
        end
        dire=Dir.parse(out);
        name=Rsync.getCurLogName(remoteName);
        out=[dire name];
    end
    function findLogFiles()
        dire=Rsync.getLogDest();
        files=Fil.find(dire,Rsync.logRe);
    end
    function getCurLogName(remoteName)
        time=Time.Sec.unixStr();
        out=sprintf(Rsync.logfrmt,tim,remoteName);
    end
    function getP()
        P={'mode','a','Rsync.validModes_i_e'; ...
           'bAsync',[],'isBool'; ...
           'bLog',[],'isBool_e';...
           'bWatch',[],'isBool_e'; ...
           'configFname','','ischar_e';
           'filesListFile','','ischar_e';
          };
    end
end
methods
    function obj=Rsync(remoteName,srcDir,destDir,direction,varargin)

        if ~Sys.isInstalled('rsync');
            error('Rsync is not installed');
        end

        obj=Args.parse(obj,Rsync.getP(),varargin{:});
        obj.term=getenv('TERM');
        if isempty(obj.bAsync)
            obj.bAsync=~isempty(obj.term);
        end
        if isempty(obj.bLog)
            obj.bAsync=~isempty(obj.term);
        end
        if isempty(obj.bWatch)
            obj.bWatch=~isempty(obj.term);
        end

        obj.remoteName=obj.parseRemoteName(remoteName);
        obj.srcDir=srcDir;
        obj.destDir=destDir;
        obj.direction=direction;

        hostsStr=obj.getHostsStr(remoteName,src,dest,direction);
        flags=obj.getFlags;
        cmd=obj.getCmd(flags,hostsStr);
        if obj.bLog
            obj.initLog();
        end
        obj.run(cmd);
    end
    function run(obj,cmd)
        [out,bSuccess]=Sys.run(cmd);
        if iscell(out)
            out=strjoin(out,newline);
        end
        if ~bSuccess && obj.bLog
            error(['Rsync encountered an error. Check log: ' obj.logFname]);
        elseif ~bSuccess  && ~obj.bLog
            error(['Rsync encountered an error:' newline '' Str.tabify(out) '']);
        elseif obj.bAsync
            disp('Running asynchronously. External process will notify you when completed')
        else
            disp('Done')
        end
    end
    function flags=getFlags(obj)
        % a=rlptgoD, recurse, links as links, permissions, times, groups, owners, devices
        % X extended, H hard as hard, E executability, u skip newer files on receiver
        switch obj.mode
        case 'db'
            flags='vaXHu';
        case 'a'
            flags='a';
        end
    end
    function initLog(obj)
        obj.logFname=obj.getLogFname(obj.remoteName);
        Fil.touch(obj.logFname);
        if isempty(obj.term)
            error('You do not have the TERM enviornment variable set.');
        end
        if obj.bWatch
            unix('%s -t %s -e "watch cat %s"',term,Rsync.termTitle, obj.logFname); %
        end
    end
    function getCmd(obj,flags,hostsStr)
        flagStr=springf('-%s',flags); %
        if ~isempty(obj.configFname)
            configStr=sprintf('--config=%s',obj.configFile'); %
        end
        if obj.bAsync
            asyncStr='&';
        else
            asyncStr='';
        end
        if obj.bLog
            logStr=sprintf('2>&1 > %s', obj.logFname); %
        else
            logStr='';
        end
        if ~isempty(obj.filesListFile)
            fnameStr=['--files-from ' obj.filesListFile];
        else
            fnameStr='';
        end
        cmd=sprintf('rsync %s %s %s %s %s', flagStr,fnameStr,configStr,hostsStr,asyncStr,logStr); %
    end
    function hostsStr=getHostsStr(obj,remoteName,src,dest,direction)
        switch direction
        case 'push'
            hostsStr=sprintf('%s %s:%s',obj.src, obj.remoteName, obj.dest); %
        case 'pull'
            hostsStr=sprintf('%s:%s %s',obj.remoteName, obj.src, obj.dest); %
        end
    end
    function remoteName=parseRemoteName(objremoteName)
        % XXX
    end
end
end
