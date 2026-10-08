function state = md5Compress(state, blocks)
%MD5COMPRESS Update an MD5 state with complete 64-byte blocks.

    arguments
        state (4, 1) uint32
        blocks (64, :) uint8
    end

    persistent constants shifts wordOrder
    if isempty(constants)
        constants = floor(abs(sin(1:64)) * 4294967296);
        shifts = [7, 12, 17, 22, 7, 12, 17, 22, ...
                  7, 12, 17, 22, 7, 12, 17, 22, ...
                  5, 9, 14, 20, 5, 9, 14, 20, ...
                  5, 9, 14, 20, 5, 9, 14, 20, ...
                  4, 11, 16, 23, 4, 11, 16, 23, ...
                  4, 11, 16, 23, 4, 11, 16, 23, ...
                  6, 10, 15, 21, 6, 10, 15, 21, ...
                  6, 10, 15, 21, 6, 10, 15, 21];
        wordOrder = [1:16, mod(5 * (0:15) + 1, 16) + 1, ...
            mod(3 * (0:15) + 5, 16) + 1, mod(7 * (0:15), 16) + 1];
    end

    words = double(blocks(1:4:end, :)) + ...
        256 * double(blocks(2:4:end, :)) + ...
        65536 * double(blocks(3:4:end, :)) + ...
        16777216 * double(blocks(4:4:end, :));

    for blockIndex = 1:size(words, 2)
        a = state(1);
        b = state(2);
        c = state(3);
        d = state(4);
        blockWords = words(:, blockIndex);

        for roundIndex = 1:64
            if roundIndex <= 16
                f = bitxor(d, bitand(b, bitxor(c, d)));
            elseif roundIndex <= 32
                f = bitxor(c, bitand(d, bitxor(b, c)));
            elseif roundIndex <= 48
                f = bitxor(b, bitxor(c, d));
            else
                f = bitxor(c, bitor(b, bitcmp(d)));
            end

            value = uint32(rem(double(a) + double(f) + ...
                constants(roundIndex) + blockWords(wordOrder(roundIndex)), ...
                4294967296));
            rotated = bitor(bitshift(value, shifts(roundIndex)), ...
                bitshift(value, shifts(roundIndex) - 32));
            a = d;
            d = c;
            c = b;
            sumValue = double(b) + double(rotated);
            if sumValue >= 4294967296
                sumValue = sumValue - 4294967296;
            end
            b = uint32(sumValue);
        end

        state = uint32(rem(double(state) + double([a; b; c; d]), ...
            4294967296));
    end
end
