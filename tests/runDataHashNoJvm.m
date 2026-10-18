% Run the maintained suites against source and standalone DataHash without Java.
% Launch with -batch and run this script by its absolute path. Use -nojvm
% when Java is available; omit it to check an unavailable Java runtime.
% Builds in a temporary folder and restores path, folder, RNG, and open files.
% Copyright (c) 2026, Stefano Pradella. See ../license.txt.

runChecks(fileparts(fileparts(mfilename('fullpath'))));

function runChecks(repositoryFolder)
    initialJvm = usejava('jvm');
    if initialJvm
        % Lazy initialization can report a JVM before detecting a missing JRE.
        try
            javaObject('java.lang.String', 'DataHash JVM availability probe');
        catch exception
            fprintf('Java initialization failed (%s): %s\n', ...
                exception.identifier, exception.message);
        end
    end
    assert(~usejava('jvm'), ...
        'Java is available. Start MATLAB with -nojvm before running this script.');
    fprintf('MATLAB R%s | %s | initial JVM=%d | JVM=%d\n', ...
        version('-release'), computer, initialJvm, usejava('jvm'));
    originalPath = path;
    originalFolder = pwd;
    originalRng = rng;
    originalFiles = openFiles();
    workFolder = tempname;
    [status, message] = mkdir(workFolder);
    assert(status, message);
    cleanup = onCleanup(@() restoreState(originalPath, originalFolder, ...
        originalRng, originalFiles, workFolder));

    % Current-folder precedence must not select a repository-root distribution.
    cd(workFolder);
    pathFolders = strsplit(originalPath, pathsep);
    repositoryPaths = startsWith(strcat(pathFolders, filesep), ...
        [repositoryFolder, filesep], 'IgnoreCase', ispc);
    isolatedPath = strjoin(pathFolders(~repositoryPaths), pathsep);
    path(isolatedPath);
    addpath(repositoryFolder);
    standaloneFolder = fullfile(workFolder, 'standalone');
    [status, message] = mkdir(standaloneFolder);
    assert(status, message);
    standaloneFile = buildDataHash(fullfile(standaloneFolder, 'DataHash.m'));
    path(isolatedPath);

    sourceFolder = fullfile(repositoryFolder, 'src');
    testFiles = {fullfile(repositoryFolder, 'tests', 'DataHashTest.m'), ...
        fullfile(repositoryFolder, 'tests', 'DataHashLegacyCompatibilityTest.m')};
    hasFixedPoint = exist('fi', 'file') == 2 && license('test', 'Fixed_Point_Toolbox');
    fprintf('Fixed-Point Designer available: %d\n', hasFixedPoint);

    for implementationIndex = 1:2
        path(isolatedPath);
        addpath(genpath(sourceFolder));
        if implementationIndex == 1
            cd(workFolder);
            expectedFile = fullfile(sourceFolder, 'DataHash.m');
            label = 'Source';
        else
            cd(standaloneFolder);
            expectedFile = standaloneFile;
            label = 'Standalone';
        end
        clear DataHash;
        assert(strcmp(which('DataHash'), expectedFile), 'Wrong DataHash implementation.');
        fprintf('\n%s: %s\n', label, which('DataHash'));
        testPath = path;
        testFolder = pwd;
        suite = testsuite(testFiles);
        if exist('DataHashCore', 'file') ~= 3
            suite = suite.selectIf(~matlab.unittest.selectors.HasTag('MD5Accelerator'));
        end
        results = run(suite);
        fprintf('%s: %d passed, %d failed, %d incomplete\n', label, ...
            sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));
        assert(strcmp(which('DataHash'), expectedFile), 'DataHash resolution changed.');
        assert(strcmp(path, testPath) && strcmp(pwd, testFolder), ...
            'The suites did not restore the path or current folder.');
        assert(isequal(rng, originalRng) && isequal(openFiles(), originalFiles), ...
            'The suites changed RNG state or leaked file handles.');
        optional = contains({results.Name}, 'fixedPoint', 'IgnoreCase', true);
        allowedSkips = optional & ~hasFixedPoint;
        assert(~any([results.Failed]) && ~any([results.Incomplete] & ~allowedSkips), ...
            '%s has failures or unexplained incomplete tests.', label);
    end

    % Repeat only essential stored vectors without source helpers to confirm
    % the generated file is self-contained.
    path(isolatedPath);
    assert(isempty(which('serializeObject')) && isempty(which('md5Digest')), ...
        'Source helpers are still on the path.');
    addpath(fullfile(repositoryFolder, 'tests'));
    regression = DataHashTest;
    compatibility = DataHashLegacyCompatibilityTest;
    fileName = fullfile(workFolder, 'abc.bin');
    [fileId, message] = fopen(fileName, 'wb');
    assert(fileId ~= -1, message);
    fileCleanup = onCleanup(@() fclose(fileId));
    assert(fwrite(fileId, uint8('abc'), 'uint8') == 3, 'Cannot write test input.');
    clear fileCleanup;
    digestNames = fieldnames(regression.digestCase);
    for caseIndex = 1:numel(digestNames)
        if endsWith(digestNames{caseIndex}, 'Abc')
            digestCase = regression.digestCase.(digestNames{caseIndex});
            assert(strcmp(DataHash(digestCase.data, digestCase.method, 'bin'), ...
                digestCase.expected), 'Isolated memory digest failed: %s', digestCase.method);
            assert(strcmp(DataHash(fileName, digestCase.method, 'file'), ...
                digestCase.expected), 'Isolated file digest failed: %s', digestCase.method);
        end
    end
    arrayCase = regression.arrayCase.nestedCell;
    assert(strcmp(DataHash(arrayCase.data), arrayCase.expected), 'Isolated serialization failed.');
    outputCases = struct2cell(regression.outputCase);
    for caseIndex = 1:numel(outputCases)
        outputCase = outputCases{caseIndex};
        assert(isequal(DataHash(outputCase.data, outputCase.options{:}), ...
            outputCase.expected), 'Isolated output format failed.');
    end
    if hasFixedPoint
        fixedPointCase = compatibility.fixedPointCase.fixedPointArray;
        assert(strcmp(DataHash(fixedPointCase.createData()), fixedPointCase.expected), ...
            'Isolated fixed-point serialization failed.');
    end
    assert(isequal(rng, originalRng) && isequal(openFiles(), originalFiles), ...
        'Isolated checks changed RNG state or leaked file handles.');
    clear cleanup;
    assert(strcmp(path, originalPath) && strcmp(pwd, originalFolder) && ...
        isequal(rng, originalRng) && isequal(openFiles(), originalFiles), ...
        'Validation did not restore the original session state.');
    fprintf('Isolated standalone checks and session cleanup passed.\n');
end

function restoreState(originalPath, originalFolder, originalRng, originalFiles, workFolder)
    cd(originalFolder);
    path(originalPath);
    rng(originalRng);
    leakedFiles = setdiff(openFiles(), originalFiles);
    for fileIndex = 1:numel(leakedFiles)
        fclose(leakedFiles(fileIndex));
    end
    rmdir(workFolder, 's');
end

function fileIds = openFiles()
    if exist('openedFiles', 'builtin') || exist('openedFiles', 'file')
        fileIds = openedFiles;
    else
        fileIds = fopen('all');
    end
    fileIds = sort(fileIds(:));
end
