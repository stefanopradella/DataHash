function state = sha1Compress(state, blocks)
%SHA1COMPRESS Update a SHA-1 state with complete 64-byte blocks.

    arguments
        state (5, 1) uint32
        blocks (64, :) uint8
    end

    persistent isLittleEndian
    if isempty(isLittleEndian)
        [~, ~, endianness] = computer;
        isLittleEndian = endianness == 'L';
    end

    % Decode big-endian message words directly, including on big-endian hosts.
    messageWords = reshape(typecast(blocks(:), 'uint32'), 16, []);
    if isLittleEndian
        messageWords = swapbytes(messageWords);
    end

    % All partial sums are below 2^35 and exactly representable in
    % double. Reduce before the saturating uint32 conversion.
    a = state(1);
    b = state(2);
    c = state(3);
    d = state(4);
    e = state(5);
    % Batch independent schedules in at most 320 KiB of uint32 storage.
    for batchStart = 1:1024:size(messageWords, 2)
        batchEnd = min(batchStart + 1023, size(messageWords, 2));
        batchCount = batchEnd - batchStart + 1;
        words = zeros(80, batchCount, 'uint32');
        words(1:16, :) = messageWords(:, batchStart:batchEnd);
        for wordIndex = 17:80
            value = bitxor(bitxor(words(wordIndex - 3, :), ...
                words(wordIndex - 8, :)), bitxor(words(wordIndex - 14, :), ...
                words(wordIndex - 16, :)));
            words(wordIndex, :) = bitor(bitshift(value, 1), bitshift(value, -31));
        end

        for blockIndex = 1:batchCount
            startA = a;
            startB = b;
            startC = c;
            startD = d;
            startE = e;
            % Five rounds return the scalar registers to their original roles.
            for roundIndex = 1:5:20
                choice = bitxor(d, bitand(b, bitxor(c, d)));
                rotated = bitor(bitshift(a, 5), bitshift(a, -27));
                sumValue = double(rotated) + double(choice) + double(e) + ...
                    1518500249 + double(words(roundIndex, blockIndex));
                e = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                b = bitor(bitshift(b, 30), bitshift(b, -2));

                choice = bitxor(c, bitand(a, bitxor(b, c)));
                rotated = bitor(bitshift(e, 5), bitshift(e, -27));
                sumValue = double(rotated) + double(choice) + double(d) + ...
                    1518500249 + double(words(roundIndex + 1, blockIndex));
                d = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                a = bitor(bitshift(a, 30), bitshift(a, -2));

                choice = bitxor(b, bitand(e, bitxor(a, b)));
                rotated = bitor(bitshift(d, 5), bitshift(d, -27));
                sumValue = double(rotated) + double(choice) + double(c) + ...
                    1518500249 + double(words(roundIndex + 2, blockIndex));
                c = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                e = bitor(bitshift(e, 30), bitshift(e, -2));

                choice = bitxor(a, bitand(d, bitxor(e, a)));
                rotated = bitor(bitshift(c, 5), bitshift(c, -27));
                sumValue = double(rotated) + double(choice) + double(b) + ...
                    1518500249 + double(words(roundIndex + 3, blockIndex));
                b = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                d = bitor(bitshift(d, 30), bitshift(d, -2));

                choice = bitxor(e, bitand(c, bitxor(d, e)));
                rotated = bitor(bitshift(b, 5), bitshift(b, -27));
                sumValue = double(rotated) + double(choice) + double(a) + ...
                    1518500249 + double(words(roundIndex + 4, blockIndex));
                a = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                c = bitor(bitshift(c, 30), bitshift(c, -2));

            end

            for roundIndex = 21:5:40
                choice = bitxor(b, bitxor(c, d));
                rotated = bitor(bitshift(a, 5), bitshift(a, -27));
                sumValue = double(rotated) + double(choice) + double(e) + ...
                    1859775393 + double(words(roundIndex, blockIndex));
                e = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                b = bitor(bitshift(b, 30), bitshift(b, -2));

                choice = bitxor(a, bitxor(b, c));
                rotated = bitor(bitshift(e, 5), bitshift(e, -27));
                sumValue = double(rotated) + double(choice) + double(d) + ...
                    1859775393 + double(words(roundIndex + 1, blockIndex));
                d = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                a = bitor(bitshift(a, 30), bitshift(a, -2));

                choice = bitxor(e, bitxor(a, b));
                rotated = bitor(bitshift(d, 5), bitshift(d, -27));
                sumValue = double(rotated) + double(choice) + double(c) + ...
                    1859775393 + double(words(roundIndex + 2, blockIndex));
                c = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                e = bitor(bitshift(e, 30), bitshift(e, -2));

                choice = bitxor(d, bitxor(e, a));
                rotated = bitor(bitshift(c, 5), bitshift(c, -27));
                sumValue = double(rotated) + double(choice) + double(b) + ...
                    1859775393 + double(words(roundIndex + 3, blockIndex));
                b = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                d = bitor(bitshift(d, 30), bitshift(d, -2));

                choice = bitxor(c, bitxor(d, e));
                rotated = bitor(bitshift(b, 5), bitshift(b, -27));
                sumValue = double(rotated) + double(choice) + double(a) + ...
                    1859775393 + double(words(roundIndex + 4, blockIndex));
                a = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                c = bitor(bitshift(c, 30), bitshift(c, -2));

            end

            for roundIndex = 41:5:60
                choice = bitxor(bitand(b, c), bitand(d, bitxor(b, c)));
                rotated = bitor(bitshift(a, 5), bitshift(a, -27));
                sumValue = double(rotated) + double(choice) + double(e) + ...
                    2400959708 + double(words(roundIndex, blockIndex));
                e = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                b = bitor(bitshift(b, 30), bitshift(b, -2));

                choice = bitxor(bitand(a, b), bitand(c, bitxor(a, b)));
                rotated = bitor(bitshift(e, 5), bitshift(e, -27));
                sumValue = double(rotated) + double(choice) + double(d) + ...
                    2400959708 + double(words(roundIndex + 1, blockIndex));
                d = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                a = bitor(bitshift(a, 30), bitshift(a, -2));

                choice = bitxor(bitand(e, a), bitand(b, bitxor(e, a)));
                rotated = bitor(bitshift(d, 5), bitshift(d, -27));
                sumValue = double(rotated) + double(choice) + double(c) + ...
                    2400959708 + double(words(roundIndex + 2, blockIndex));
                c = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                e = bitor(bitshift(e, 30), bitshift(e, -2));

                choice = bitxor(bitand(d, e), bitand(a, bitxor(d, e)));
                rotated = bitor(bitshift(c, 5), bitshift(c, -27));
                sumValue = double(rotated) + double(choice) + double(b) + ...
                    2400959708 + double(words(roundIndex + 3, blockIndex));
                b = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                d = bitor(bitshift(d, 30), bitshift(d, -2));

                choice = bitxor(bitand(c, d), bitand(e, bitxor(c, d)));
                rotated = bitor(bitshift(b, 5), bitshift(b, -27));
                sumValue = double(rotated) + double(choice) + double(a) + ...
                    2400959708 + double(words(roundIndex + 4, blockIndex));
                a = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                c = bitor(bitshift(c, 30), bitshift(c, -2));

            end

            for roundIndex = 61:5:80
                choice = bitxor(b, bitxor(c, d));
                rotated = bitor(bitshift(a, 5), bitshift(a, -27));
                sumValue = double(rotated) + double(choice) + double(e) + ...
                    3395469782 + double(words(roundIndex, blockIndex));
                e = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                b = bitor(bitshift(b, 30), bitshift(b, -2));

                choice = bitxor(a, bitxor(b, c));
                rotated = bitor(bitshift(e, 5), bitshift(e, -27));
                sumValue = double(rotated) + double(choice) + double(d) + ...
                    3395469782 + double(words(roundIndex + 1, blockIndex));
                d = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                a = bitor(bitshift(a, 30), bitshift(a, -2));

                choice = bitxor(e, bitxor(a, b));
                rotated = bitor(bitshift(d, 5), bitshift(d, -27));
                sumValue = double(rotated) + double(choice) + double(c) + ...
                    3395469782 + double(words(roundIndex + 2, blockIndex));
                c = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                e = bitor(bitshift(e, 30), bitshift(e, -2));

                choice = bitxor(d, bitxor(e, a));
                rotated = bitor(bitshift(c, 5), bitshift(c, -27));
                sumValue = double(rotated) + double(choice) + double(b) + ...
                    3395469782 + double(words(roundIndex + 3, blockIndex));
                b = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                d = bitor(bitshift(d, 30), bitshift(d, -2));

                choice = bitxor(c, bitxor(d, e));
                rotated = bitor(bitshift(b, 5), bitshift(b, -27));
                sumValue = double(rotated) + double(choice) + double(a) + ...
                    3395469782 + double(words(roundIndex + 4, blockIndex));
                a = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
                c = bitor(bitshift(c, 30), bitshift(c, -2));

            end

            sumValue = double(startA) + double(a);
            a = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
            sumValue = double(startB) + double(b);
            b = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
            sumValue = double(startC) + double(c);
            c = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
            sumValue = double(startD) + double(d);
            d = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
            sumValue = double(startE) + double(e);
            e = uint32(sumValue - 4294967296 * fix(sumValue * 2^-32));
        end
    end
    state = [a; b; c; d; e];
end
