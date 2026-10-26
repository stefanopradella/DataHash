function outputFile = buildDataHashToolbox()
    %buildDataHashToolbox - Package the release using matlab.toml metadata
    %   outputFile = buildDataHashToolbox() packages the existing standalone
    %   function, Linux and Windows accelerators, and license.
    %   Metadata and the output location are defined in matlab.toml.
    %   Returns the absolute output path as a character vector.
    %
    %   Call from the repository root after building both platform binaries
    %   and the standalone function. Packaging requires MATLAB R2026b;
    %   the installed toolbox supports the releases specified in matlab.toml.
    %
    %   See also buildDataHash, buildDataHashMex

    % Copyright (c) 2026, Stefano Pradella. See license.txt.

    copyfile('license.txt', 'release');
    options = matlab.addons.toolbox.ToolboxOptions('matlab.toml');
    options.ToolboxFiles = fullfile('release', ["DataHash.m", ...
        "DataHashCore.mexa64", "DataHashCore.mexw64", "license.txt"]);

    % The TOML loader omits these File Exchange settings in R2026b.
    options.UseLicenseBSD = true;
    options.SupportedPlatforms.MatlabOnline = true;
    matlab.addons.toolbox.packageToolbox(options);
    outputFile = char(options.OutputFile);
end
