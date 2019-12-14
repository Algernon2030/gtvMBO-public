% =========================================================================
% Title: Code to demo gtvMVO method using Urban data
%   for "Blind Hyperspectral Unmixing Based on a Graph Total Variation
%   Regularization" by Jing Qin, Harlin Lee, Jocelyn T. Chi, Lucas Drumetz, 
%   Jocelyn Chanussot, Yifei Lou, and Andrea L. Bertozzi.
% =========================================================================

%%  Prep workspacce

close all;
clear;
clc;

seed = 1;
rng(seed);

addpath(genpath('./'));
resultsFolder = 'results/urban';

if ~exist('results', 'dir')
    mkdir('results')
end
if ~exist(resultsFolder, 'dir')
    mkdir(resultsFolder)
end

fname = fullfile(resultsFolder,'urban_output.mat');

%% Load Urban dataset
load('data/urban/Urban_R162.mat');
load('data/urban/end4_groundTruth.mat');

%% Set up experiments

A_ref = A;
S_ref = M;

clear A M;

P = nEnd; % number of endmembers
[L, N] = size(Y);
n = nRow;
m = nCol;
X = Y/maxValue;
clear nRow nCol Y 

tol = 1e-3;
errs = zeros(13, 6);
seed = 1;
rng(seed);

%% FCLSU
c = 1;

% Get S using VCA
bundle_nbr = 10; % number of VCA runs
percent = 10; % percentage of pixels considered in each run
[groups, bundle] = batchvca(X, P, bundle_nbr, percent, seed); % extract endmembers and cluster them into groups

tic
disp('FCLSU bundle')
A_FCLSU = FCLSU(X, bundle)'; % abundance is initialized as A_FCLSU_bundle for all other algorithms
t = toc;

[A_init,~] = bundle2global(A_FCLSU,bundle,groups);
S_init = [];
for idx = 1:P
    s = mean(bundle(:, groups == idx),2);
    S_init = [S_init, s];
end
S_init = max(S_init,0);
[A_init, S_init, nmse] = find_perm(A_ref, A_init, S_init);

% Save results
save(fname, 'A_FCLSU', 'A_init', 'S_init');

errs(1, c) = RMSE(X, S_init*A_init);
errs(2, c) = nMSE(X, S_init*A_init);
errs(3, c) = RMSE(S_ref, S_init);
errs(4, c) = nMSE(S_ref, S_init);
errs(5, c) = SAM(S_ref, S_init);
errs(6, c) = RMSE(A_ref, A_init);
errs(7, c) = nMSE(A_ref, A_init);
errs(8, c) = Inf;
errs(9, c) = t;
errs(10, c) = Inf;
errs(11, c) = Inf;
errs(12, c) = Inf;
errs(13, c) = Inf;

%% Fractional
c = c + 1;
disp('fractional')

para_fr.method = 'fractional';
para_fr.fraction = 1/10;
para_fr.itermax = 300;
para_fr.plot_flag = 0;
para_fr.lambda = 10^(-0.5);
para_fr.rho = 10;
para_fr.tol = tol;

tic;
[A_frac, optim_struct] = social_unmixing(X,bundle,groups,A_FCLSU, ...
        para_fr.lambda,para_fr.rho,para_fr.itermax,...
        para_fr.method,para_fr.fraction,para_fr.tol,0);
t_frac = toc;

para_fr.iter = optim_struct.iter;

A_frac = get_A(A_frac, groups, P);
    
[A_frac, ~] = find_perm2(A_ref, A_frac);
    
% (Note: No S obtained via this method)
errs(1, c) = RMSE(X, S_init*A_frac);
errs(2, c) = nMSE(X, S_init*A_frac);
errs(3, c) = Inf;
errs(4, c) = Inf;
errs(5, c) = Inf;
errs(6, c) = RMSE(A_ref, A_frac);
errs(7, c) = nMSE(A_ref, A_frac);
errs(8, c) = Inf;
errs(9, c) = t_frac;
errs(10, c) = para_fr.lambda; 
errs(11, c) = para_fr.rho; 
errs(12, c) = Inf;
errs(13, c) = para_fr.iter;

save(fname, '-append', 'A_frac', 'para_fr', 'errs');

%% 2dTV
c = c+1;
disp('2dTV');
para_tv.maxiter = 1000;
para_tv.m = m;
para_tv.n = n;
para_tv.lambda = 10^(-2.25);

tic;
A_TV = sunsal_vtv(S_init,X,'LAMBDA_1',0, 'LAMBDA_VTV', para_tv.lambda, 'X0', A_init, 'IM_SIZE', [para_tv.m,para_tv.n],  'POSITIVITY', 'yes', 'ADDONE', 'no', 'VERBOSE', 'no','AL_ITERS', para_tv.maxiter); % do not pay attention to the "'ADDONE', 'no'" bit, the sum to one constraint is actually enforced.
t_2d = toc;

para_tv.iter = para_tv.maxiter;

[A_TV, ~] = find_perm2(A_ref, A_TV);

errs(1, c) = RMSE(X, S_init*A_TV);
errs(2, c) = nMSE(X, S_init*A_TV);
errs(3, c) = Inf;
errs(4, c) = Inf;
errs(5, c) = Inf;
errs(6, c) = RMSE(A_ref, A_TV);
errs(7, c) = nMSE(A_ref, A_TV);
errs(8, c) = Inf;
errs(9, c) = t_2d;
errs(10, c) = para_tv.lambda; 
errs(11, c) = Inf; 
errs(12, c) = Inf;
errs(13, c) = para_tv.iter;

save(fname, '-append', 'A_TV', 'para_tv');

%% Nystrom extension
disp('Nystrom extension');
sigma = 5;

tic
[V, Sigma] = laplacian_nystrom(X', 3, floor(0.001*N), sigma, seed);
t_nystrom = toc

save(fname, '-append', 'V', 'Sigma');

%% Graph Laplacian
c = c + 1;

para_gL.method = 'graphL';
para_gL.tol = tol;
para_gL.m = m;
para_gL.n = n;
para_gL.V = V;
para_gL.S = Sigma;
para_gL.itermax = 10;
para_gL.lambda = 10^(-3.25);
para_gL.rho = 10^(-1.25);
para_gL.gamma = 10^(4.75);

disp('graph Laplacian');
tic;
[S_graphL, A_graphL, iter] = unmixing(X, S_init, A_init, para_gL);
t_gL = toc;
para_gL.iter = iter;

[A_graphL, S_graphL, ~] = find_perm(A_ref, A_graphL, S_graphL);

errs(1, c) = RMSE(X, S_graphL*A_graphL);
errs(2, c) = nMSE(X, S_graphL*A_graphL);
errs(3, c) = RMSE(S_ref, S_graphL);
errs(4, c) = nMSE(S_ref, S_graphL);
errs(5, c) = SAM(S_ref, S_graphL);
errs(6, c) = RMSE(A_ref, A_graphL);
errs(7, c) = nMSE(A_ref, A_graphL);
errs(8, c) = t_nystrom;
errs(9, c) = t_gL;
errs(10, c) = para_gL.lambda;
errs(11, c) = para_gL.rho;
errs(12, c) = para_gL.gamma;
errs(13, c) = para_gL.iter;

clear para_gL.m para_gL.n para_gL.V para_gL.S
save(fname, '-append', 'A_graphL', 'S_graphL', 'errs', 'para_gL');

%% gtvMBO
c = c + 1;

para_mbo.method = 'gtvMBO';
para_mbo.tol = tol;
para_mbo.m = m;
para_mbo.n = n;
para_mbo.V = V;
para_mbo.S = Sigma;
para_mbo.itermax = 10;
para_mbo.dt = 0.01;
para_mbo.lambda = 10^(-6);
para_mbo.rho = 10^(-5.5);
para_mbo.gamma = 10^(4.75);

disp('gtvMBO');

tic;
[S_MBO, A_MBO, iter] = unmixing(X, S_init, A_init, para_mbo);
t_MBO = toc;
para_mbo.iter = iter;

[A_MBO, S_MBO, ~] = find_perm(A_ref, A_MBO, S_MBO);

errs(1, c) = RMSE(X, S_MBO*A_MBO);
errs(2, c) = nMSE(X, S_MBO*A_MBO);
errs(3, c) = RMSE(S_ref, S_MBO);
errs(4, c) = nMSE(S_ref, S_MBO);
errs(5, c) = SAM(S_ref, S_MBO);
errs(6, c) = RMSE(A_ref, A_MBO);
errs(7, c) = nMSE(A_ref, A_MBO);
errs(8, c) = t_nystrom;
errs(9, c) = t_MBO;
errs(10, c) = para_mbo.lambda; 
errs(11, c) = para_mbo.rho; 
errs(12, c) = para_mbo.gamma;
errs(13, c) = para_mbo.iter;

clear para_mbo.m para_mbo.n para_mbo.V para_mbo.S
save(fname, '-append', 'A_MBO', 'S_MBO', 'errs','para_mbo');

%% gtvMBO fixed ratio
c = c+1;

para_mbo_fixed.method = 'gtvMBO';
para_mbo_fixed.tol = tol;

para_mbo_fixed.m = m;
para_mbo_fixed.n = n;

para_mbo_fixed.V = V;
para_mbo_fixed.S = Sigma;

para_mbo_fixed.dt = 0.01;
para_mbo_fixed.itermax = 10;
para_mbo_fixed.lambda = 10^(-2.5);
para_mbo_fixed.rho = para_mbo_fixed.lambda;
para_mbo_fixed.gamma = para_mbo_fixed.lambda*10^7;

disp('gtvMBO fixed ratio');

tic;
[S_MBO_fixed, A_MBO_fixed, iter] = unmixing(X, S_init, A_init, para_mbo_fixed);
t_MBO_fixed = toc;
para_mbo_fixed.iter = iter;

[A_MBO_fixed, S_MBO_fixed, ~] = find_perm(A_ref, A_MBO_fixed, S_MBO_fixed);

errs(1, c) = RMSE(X, S_MBO_fixed*A_MBO_fixed);
errs(2, c) = nMSE(X, S_MBO_fixed*A_MBO_fixed);
errs(3, c) = RMSE(S_ref, S_MBO_fixed);
errs(4, c) = nMSE(S_ref, S_MBO_fixed);
errs(5, c) = SAM(S_ref, S_MBO_fixed);
errs(6, c) = RMSE(A_ref, A_MBO_fixed);
errs(7, c) = nMSE(A_ref, A_MBO_fixed);
errs(8, c) = t_nystrom;
errs(9, c) = t_MBO_fixed;
errs(10, c) = para_mbo_fixed.lambda; 
errs(11, c) = para_mbo_fixed.rho; 
errs(12, c) = para_mbo_fixed.gamma;
errs(13, c) = para_mbo_fixed.iter;

clear para_mbo_fixed.m para_mbo_fixed.n para_mbo_fixed.V para_mbo_fixed.S
save(fname, '-append', 'A_MBO_fixed', 'S_MBO_fixed', 'errs','para_mbo_fixed');

%% Plot results

% Look at error table
format longG;
errs

% Plot results for A
fig = figure;
[ha, ~] = tight_subplot(7, P, [.03 .03], [.03 .03], [0 0]);
for i = 1:P
    axes(ha(i));
    imshow(reshape(A_ref(i,:), m,n), []);axis off;colormap gray
    title('Reference')
end
for i = 1:P
    axes(ha(i+P));
    imshow(reshape(A_init(i,:), m,n), []); axis off;
    title('FCLSU')
end
for i = 1:P
    axes(ha(i+2*P));
    imshow(reshape(A_frac(i,:),m,n),[]); axis off;
    title('fractional')
end
for i = 1:P
    axes(ha(i+3*P));
    imshow(reshape(A_TV(i,:),m,n),[]); axis off;
    title('2dTV')
end
for i = 1:P
    axes(ha(i+4*P));
    imshow(reshape(A_graphL(i,:),m,n),[]); axis off;
    title('graphL')
end
for i = 1:P
    axes(ha(i+5*P));
    imshow(reshape(A_MBO(i,:),m,n),[]);axis off;
    title('gtvMBO')
end
for i = 1:P
    axes(ha(i+6*P));
    imshow(reshape(A_MBO(i,:),m,n),[]);axis off;
    title('gtvMBO fixed ratio')
end
saveas(fig, fullfile(resultsFolder,'urbanResultsA.jpg'));

% Save A plots (by row)
for i = 1:P
    f = figure('visible','off'); imshow(reshape(A_ref(i,:), m,n), []);
    pngFileName = sprintf('ref%d.png', i);
    fullFileName = fullfile(resultsFolder, pngFileName);
    export_fig(fullFileName);
    
	f = figure('visible','off'); imshow(reshape(A_init(i,:), m,n), []); 
	pngFileName = sprintf('fclsu%d.png', i);
    fullFileName = fullfile(resultsFolder, pngFileName);
    export_fig(fullFileName);   
    
    f = figure('visible','off'); imshow(reshape(A_frac(i,:), m,n), []); 
    pngFileName = sprintf('frac%d.png', i);
    fullFileName = fullfile(resultsFolder, pngFileName);
    export_fig(fullFileName);
     
    f = figure('visible','off'); imshow(reshape(A_TV(i,:), m,n), []); 
    pngFileName = sprintf('tv%d.png', i);
    fullFileName = fullfile(resultsFolder, pngFileName);
    export_fig(fullFileName);
    
    f = figure('visible','off'); imshow(reshape(A_graphL(i,:), m,n), []);
    pngFileName = sprintf('graphl%d.png', i);
    fullFileName = fullfile(resultsFolder, pngFileName);
    export_fig(fullFileName);
    
    f = figure('visible','off'); imshow(reshape(A_MBO(i,:), m,n), []); 
    pngFileName = sprintf('mbo%d.png', i);
    fullFileName = fullfile(resultsFolder, pngFileName);
    export_fig(fullFileName);
    
    f = figure('visible','off'); imshow(reshape(A_MBO_fixed(i,:), m,n), []); 
    pngFileName = sprintf('mbo_fixed%d.png', i);
    fullFileName = fullfile(resultsFolder, pngFileName);
    export_fig(fullFileName);
end

% Plot results for S (FCLSU and fractional don't produce S)
figout3 = figure;
subplot(2,3,1); plot(S_ref); title('Reference');
subplot(2,3,2); plot(S_init); title('VCA');
subplot(2,3,3); plot(S_graphL); title('GraphL');
subplot(2,3,4); plot(S_MBO); title('gtvMBO');
subplot(2,3,5); plot(S_MBO_fixed); title('gtvMBO fixed ratio');

export_fig(fullfile(resultsFolder,'urbanResultsS.png'));
export_fig(fullfile(resultsFolder,'urbanResultsS_transparent.png'), '-transparent');

% Save S plots

f = figure('visible','off'); plot(S_ref, 'LineWidth', 2); 
axis square;
axis([0 170 0 0.45])
set(gca,'FontSize',24)
pngFileName = 'S_ref.png';
fullFileName = fullfile(resultsFolder, pngFileName);
export_fig(fullFileName, '-transparent');

f = figure('visible','off'); plot(S_init, 'LineWidth', 2); 
axis square;
axis([0 170 0 0.45])
set(gca,'FontSize',24)
pngFileName = 'S_vca.png';
fullFileName = fullfile(resultsFolder, pngFileName);
export_fig(fullFileName, '-transparent');

f = figure('visible','off'); plot(S_graphL, 'LineWidth', 2); 
axis square;
axis([0 170 0 0.45])
set(gca,'FontSize',24)
pngFileName = 'S_graphL.png';
fullFileName = fullfile(resultsFolder, pngFileName);
export_fig(fullFileName, '-transparent');

f = figure('visible','off'); plot(S_MBO, 'LineWidth', 2); 
lgd = legend('Parking','Roofs','Chairs','Vegetation','Location', 'eastoutside');
lgd.FontSize = 36;
legend('boxoff')     
axis square;
axis([0 170 0 0.45])
set(gca,'FontSize',20)
pngFileName = 'S_mbo.png';
fullFileName = fullfile(resultsFolder, pngFileName);
export_fig(fullFileName, '-transparent');

% Save laTeX table
rowNames = {'RMSE$(X, \hat{S}\hat{A})$','nMSE$(X, \hat{S}\hat{A})$','RMSE$(S, \hat{S})$','nMSE$(S, \hat{S})$','SAM$(S, \hat{S})$','RMSE$(A, \hat{A})$','nMSE$(A, \hat{A})$', 'Graph time (sec)', 'time (sec)','$\lambda$','$\rho$','$\gamma$', 'Iterations'};
colNames = {'FCLSU','FRAC','TV','GraphL','gtvMBO'};
errsTable = array2table(errs(1:13,1:5),'RowNames',rowNames,'VariableNames',colNames)
table2latexfancy(errsTable, fullfile(resultsFolder,'errsTable.tex'));

