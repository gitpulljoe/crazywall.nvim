def encode_char(char, offset):
    return chr(
        (
            (ord(char) - ord(" ") +  offset) %
                (ord("~") - ord(" ") + 1)
        ) + (ord(" "))
    )

def caesar_cipher_encode(plaintext, offset):
    return "".join(encode_char(c, offset) for c in plaintext)

def caesar_cipher_decode(plaintext, offset):
    return "".join(encode_char(c, -offset) for c in plaintext)
