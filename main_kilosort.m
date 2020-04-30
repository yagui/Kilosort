%% you need to change most of the paths in this block

base_path = '/home/gridsan/aburman/kilosort/';
addpath(genpath(strcat(base_path,'Kilosort2'))) % path to kilosort folder
addpath(strcat(base_path,'npy-matlab/npy-matlab'))

pathToYourConfigFile = pwd; % take from Github folder and put it somewhere else (together with the master_file)
run(fullfile(pathToYourConfigFile, 'config.m'))
rootH = strcat(base_path,'tmp/');
tempnum = pad(getenv('SLURM_JOBID'),8,'left','0');
ops.fproc  = fullfile(rootH, ['temp_wh_' tempnum '.dat']); % proc file on a fast SSD
disp(ops.fproc)

ops.trange    = [0 Inf]; % time range to sort
ops.NchanTOT  = 32; % total number of channels in your recording

% the binary file is in this folder
rootZ = strcat(pwd,'/out/');

%% this block runs all the steps of the algorithm
fprintf('Looking for data inside %s \n', rootZ)
chanMapFile = 'chanMap.mat';
ops.chanMap = fullfile(rootZ, chanMapFile);
fs          = 'continuous.dat';
ops.fbinary = fullfile(rootZ, fs);

% main parameter changes from Kilosort2 to v2.5
ops.sig        = 20;  % spatial smoothness constant for registration
ops.fshigh     = 300; % high-pass more aggresively
ops.nblocks    = 5; % blocks for registration. 0 turns it off, 1 does rigid registration. Replaces "datashift" option. 

% preprocess data to create temp_wh.dat
rez = preprocessDataSub(ops);
%
% NEW STEP TO DO DATA REGISTRATION
rez = datashift2(rez, 1); % last input is for shifting data

% ORDER OF BATCHES IS NOW RANDOM, controlled by random number generator
iseed = 1;
                 
% main tracking and template matching algorithm
rez = learnAndSolve8b(rez, iseed);

% OPTIONAL: remove double-counted spikes - solves issue in which individual spikes are assigned to multiple templates.
% See issue 29: https://github.com/MouseLand/Kilosort/issues/29
%rez = remove_ks2_duplicate_spikes(rez);

% final merges
rez = find_merges(rez, 1);

% final splits by SVD
rez = splitAllClusters(rez, 1);

% decide on cutoff
rez = set_cutoff(rez);
% eliminate widely spread waveforms (likely noise)
rez.good = get_good_units(rez);

fprintf('found %d good units \n', sum(rez.good>0))

%% Ensure all GPU arrays are transferred to CPU side before saving to .mat
%rez_fields = fieldnames(rez);
%for i = 1:numel(rez_fields)
%    field_name = rez_fields{i};
%    if(isa(rez.(field_name), 'gpuArray'))
%        rez.(field_name) = gather(rez.(field_name));
%    end
%end

% write to Phy
fprintf('Saving results to Phy  \n')
rezToPhy(rez, rootZ);

% delete temp file
fprintf('Deleting temp file \n')
if exist(ops.fproc, 'file')==2
  delete(ops.fproc);
end

fprintf('Exiting \n')
exit
