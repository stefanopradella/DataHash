classdef DataHashPerformanceTest < matlab.unittest.TestCase
    % Speed check adapted from uTest_DataHash.m.
    % Copyright (c) 2009-2019, Jan Simon. See ../../license.txt.

    methods (TestClassSetup)
        function addSourceFolder(testCase)
            repositoryFolder = fileparts(fileparts(fileparts( ...
                mfilename('fullpath'))));
            sourceFolder = fullfile(repositoryFolder, 'src');
            originalPath = path;
            testCase.addTeardown(@path, originalPath);
            addpath(sourceFolder, fullfile(sourceFolder, 'md5'));
        end
    end

    methods (Test, TestTags = {'Performance'})
        function speedAndOptionalGetMD5Comparison(testCase)
            originalRng = rng;
            testCase.addTeardown(@rng, originalRng);
            rng(0, 'twister');

            delay = 2;
            getmd5_M = which('GetMD5.m');
            getmd5_X = which(['GetMD5.', mexext]);
            if ~isempty(getmd5_M) && ~isempty(getmd5_X)
                sourceText = fileread(getmd5_M);
                hasGetMD5 = any(strfind(sourceText, 'Author: Jan Simon'));
            else
                hasGetMD5 = false;
            end

            if hasGetMD5
                fprintf('  Data size:     DataHash:      GetMD5:\n');
            else
                fprintf('  Data size:     DataHash:\n');
            end

            for dataLength = [10, 100, 1000, 10000, 1e5, 1e6, 1e7, 1e8]
                [number, unit] = DataHashPerformanceTest.unitPrint( ...
                    dataLength, false);
                fprintf('%12s ', [number, ' ', unit]);
                data = randi([0, 255], 1, dataLength, 'uint8');

                iterations = 0;
                elapsed = 0;
                tic;
                while elapsed < delay || iterations < 2
                    hash = DataHash(data, 'MD5', 'bin', 'uint8');
                    iterations = iterations + 1;
                    elapsed = toc;
                end
                callsPerSecond = iterations / elapsed;
                [number, unit] = DataHashPerformanceTest.unitPrint( ...
                    callsPerSecond * dataLength, true);

                if hasGetMD5
                    iterations = 0;
                    elapsed = 0;
                    tic;
                    while elapsed < delay || iterations < 2
                        referenceHash = GetMD5(data, 'binary', 'uint8');
                        iterations = iterations + 1;
                        elapsed = toc;
                    end
                    referenceCallsPerSecond = iterations / elapsed;
                    [referenceNumber, referenceUnit] = ...
                        DataHashPerformanceTest.unitPrint( ...
                        referenceCallsPerSecond * dataLength, true);
                    fprintf('%8s %s/s  %9s %s/s\n', ...
                        number, unit, referenceNumber, referenceUnit);
                    testCase.verifyEqual(hash, referenceHash);
                else
                    fprintf('%8s %s/s\n', number, unit);
                end
            end
        end
    end

    methods (Static, Access = private)
        function [number, unit] = unitPrint(value, useMB)
            if value >= 1e6 || useMB
                number = sprintf('%.1f', value / 1e6);
                unit = 'MB';
            elseif value >= 1e3
                number = sprintf('%.1f', value / 1000);
                unit = 'kB';
            else
                number = sprintf('%g', value);
                unit = ' B';
            end
        end
    end
end
