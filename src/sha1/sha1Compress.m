function state = sha1Compress(state, blocks)
%SHA1COMPRESS Update a SHA-1 state with complete 64-byte blocks.

    arguments
        state (5, 1) uint32
        blocks (64, :) uint8
    end

    messageWords = uint32(16777216 * double(blocks(1:4:end, :)) + ...
        65536 * double(blocks(2:4:end, :)) + ...
        256 * double(blocks(3:4:end, :)) + ...
        double(blocks(4:4:end, :)));
    wordMask = uint64(4294967295);

    for blockIndex = 1:size(messageWords, 2)
        words = zeros(80, 1, 'uint32');
        words(1:16) = messageWords(:, blockIndex);
        for wordIndex = 17:80
            value = bitxor(bitxor(words(wordIndex - 3), ...
                words(wordIndex - 8)), bitxor(words(wordIndex - 14), ...
                words(wordIndex - 16)));
            words(wordIndex) = bitor(bitshift(value, 1), ...
                bitshift(value, -31));
        end

        a = state(1);
        b = state(2);
        c = state(3);
        d = state(4);
        e = state(5);

        for roundIndex = 1:80
            if roundIndex <= 20
                f = bitxor(d, bitand(b, bitxor(c, d)));
                constant = uint64(1518500249);
            elseif roundIndex <= 40
                f = bitxor(b, bitxor(c, d));
                constant = uint64(1859775393);
            elseif roundIndex <= 60
                f = bitxor(bitand(b, c), bitand(d, bitxor(b, c)));
                constant = uint64(2400959708);
            else
                f = bitxor(b, bitxor(c, d));
                constant = uint64(3395469782);
            end

            rotated = bitor(bitshift(a, 5), bitshift(a, -27));
            sumValue = uint64(rotated) + uint64(f) + uint64(e) + ...
                constant + uint64(words(roundIndex));
            temporary = uint32(bitand(sumValue, wordMask));
            e = d;
            d = c;
            c = bitor(bitshift(b, 30), bitshift(b, -2));
            b = a;
            a = temporary;
        end

        workingState = [a; b; c; d; e];
        for wordIndex = 1:5
            sumValue = uint64(state(wordIndex)) + ...
                uint64(workingState(wordIndex));
            state(wordIndex) = uint32(bitand(sumValue, wordMask));
        end
    end
end
