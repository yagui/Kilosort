%% you need to change most of the paths in this block

base_path = '/home/gridsan/aburman/kilosort/';
addpath(genpath(strcat(base_path,'Kilosort'))) % path to kilosort folder
addpath(strcat(base_path,'npy-matlab/npy-matlab'))
pathToYourConfigFile = pwd; % take from Github folder and put it somewhere else (together with the master_file)
run(fullfile(pathToYourConfigFile, 'config.m'))
rootH = strcat(base_path,'tmp/');
tempnum = pad(getenv('SLURM_JOBID'),8,'left','0');
ops.fproc  = fullfile(rootH, ['temp_wh_' tempnum '.dat']); % proc file on a fast SSD
disp(ops.fproc)

ops.trange = [0 Inf]; % time range to sort

% find the binary file
rootZ = strcat(pwd,'/out/');
ops.rootZ = rootZ;
ops.figsdir=strcat(rootZ,'/figs');
mkdir(ops.figsdir);

fprintf('Looking for data inside %s \n', rootZ)
chanMapFile = 'chanMap.mat';
fs          = 'continuous.dat';
ops.chanMap = fullfile(rootZ, chanMapFile);
ops.fbinary = fullfile(rootZ, fs);

%% this block runs all the steps of the algorithm

% main parameter changes from Kilosort2 to v2.5
ops.sig        = 20;  % spatial smoothness constant for registration
ops.fshigh     = 300; % high-pass more aggresively
ops.nblocks    = 5; % blocks for registration. 0 turns it off, 1 does rigid registration. Replaces "datashift" option. 

% main parameter changes from Kilosort2.5 to v3.0
ops.Th       = [9 9];


% Kilosort Starts
rez                = preprocessDataSub(ops);
rez                = datashift2(rez, 1);

[rez, st3, tF]     = extract_spikes(rez);

rez                = template_learning(rez, tF, st3);

[rez, st3, tF]     = trackAndSort(rez);

rez                = final_clustering(rez, tF, st3);

rez                = find_merges(rez, 1);

fprintf('Saving results to Phy  \n')
rezToPhy2(rez, rootZ);

% delete temp file
fprintf('Deleting temp file \n')
if exist(ops.fproc, 'file')==2
  delete(ops.fproc);
end

fprintf('Exiting \n')
exit
