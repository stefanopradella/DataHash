function outputFile = buildDataHashMex(outputFolder)
    %buildDataHashMex - Compile the optional hashing MEX accelerator
    %   OUTPUTFILE = buildDataHashMex() builds DataHashCore in the repository's
    %   release folder and returns its absolute path as a character vector.
    %   The default release folder is created if necessary. Requires
    %   MATLAB R2019b or later and a C compiler configured with MEX -setup C.
    %   MATLAB Coder and external hashing libraries are not required.
    %   Build the same C source on each target OS: DataHashCore.mexw64 on
    %   Windows and DataHashCore.mexa64 on Linux. Each binary checks CPU
    %   features at runtime and uses the scalar core when unavailable.
    %
    %   OUTPUTFILE = buildDataHashMex(OUTPUTFOLDER) builds into an existing
    %   folder specified by a character vector or scalar string. Compilation
    %   uses the interleaved complex C Matrix API (-R2018a) and optimization
    %   (-O). An existing binary is replaced only after compilation succeeds.
    %   Compiler diagnostics propagate to the caller.
    %   Keep baseline x64 compiler settings; global AVX/SHA flags are
    %   rejected because they could put unsupported instructions in dispatch
    %   or fallback code. MSVC 2017 or later and GCC support the x64 paths.
    %
    %   See also DataHash, buildDataHash, MEX, MEXEXT

    % Copyright (c) 2026, Stefano Pradella. See license.txt.

    arguments
        outputFolder (1, 1) string = ...
            string(fullfile(fileparts(mfilename('fullpath')), 'release'))
    end

    if nargin == 0 && ~isfolder(outputFolder)
        [status, message] = mkdir(char(outputFolder));
        if ~status
            error('buildDataHashMex:CreateFolder', '%s', message);
        end
    end

    % FILEATTRIB retains R2019b support and resolves an absolute folder name.
    [status, folderInfo] = fileattrib(char(outputFolder));
    if ~status || ~isscalar(folderInfo) || ~folderInfo.directory
        error('buildDataHashMex:MissingOutputFolder', ...
            'The output folder must exist: %s', outputFolder);
    end
    outputFolder = folderInfo.Name;
    repositoryFolder = fileparts(mfilename('fullpath'));
    sourceFile = fullfile(repositoryFolder, 'src', 'mex', 'DataHashCore.c');
    if ~isfile(sourceFile)
        error('buildDataHashMex:MissingSource', ...
            'Cannot find the MEX source: %s', sourceFile);
    end
    if isempty(mex.getCompilerConfigurations('C', 'Selected'))
        error('buildDataHashMex:NoCompiler', ...
            'Configure a supported C compiler with mex -setup C, then retry.');
    end

    buildFolder = tempname(outputFolder);
    [status, message] = mkdir(buildFolder);
    if ~status
        error('buildDataHashMex:CreateFolder', '%s', message);
    end
    cleanup = onCleanup(@() rmdir(buildFolder, 's'));
    mex('-R2018a', '-O', '-outdir', buildFolder, ...
        '-output', 'DataHashCore', sourceFile);
    binaryName = ['DataHashCore.', mexext];
    compiledFile = fullfile(buildFolder, binaryName);
    if ~isfile(compiledFile)
        error('buildDataHashMex:MissingBinary', ...
            'The compiler did not produce %s.', compiledFile);
    end
    outputFile = fullfile(outputFolder, binaryName);
    clear DataHashCore;
    [status, message] = movefile(compiledFile, outputFile, 'f');
    if ~status
        error('buildDataHashMex:ReplaceFailed', ...
            'Cannot replace the accelerator: %s', message);
    end
    rehash;
end
