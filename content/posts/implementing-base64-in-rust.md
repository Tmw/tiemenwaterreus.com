---
title: Implementing Base64 from scratch in Rust
date: 2021-04-03T12:13:03+02:00
draft: false
description: Implementing a Base64 encoder and decoder from scratch in Rust.
tags: Base64, Rust, encoding, decoding
icon: 🧲
---

In this article we'll take a crack at implementing a Base64 encoder and decoder from scratch using Rust. Base64 is quite an easy and fun algorithm to implement, so let's dive right in!

## What is Base64?
Base64 is an encoding algorithm that has its primary use in encoding a binary blob to a stringified version using 64 different ASCII characters. For example [email attachments](https://en.wikipedia.org/wiki/Email_attachment) or [embedding image data](https://en.wikipedia.org/wiki/Data_URI_scheme) directly into a `img` tag.

Base64 works by chunking the original binary in chunks of 3 bytes (21 bits) and splitting these 21 bits into 4 groups of 6 bits. These 6 bits translate to a number anywhere from 0 (`0b000000`) to 63 (`0b111111`) which are mapped to 64 ASCII characters.

The original Base64 alphabet uses `A-Z` uppercase, `a-z` lowercase, the digits `0` through `9` and special characters `+` and `/`. The `=` is used for padding at the end of the output string, so that we always end on a multiple of four bytes. This is Base64 in a nutshell, but if you'd like to dive deeper, give [this excellent article](https://medium.com/swlh/powering-the-internet-with-base64-d823ec5df747) a read!

**TODO** Include small illustration of how Base64 works (stitching multiple bytes together into 6 bit chunks.

## The main problems to solve

**Encoding data** to Base64 is fairly simple:
- Take the original binary input
- Chop this stream up in slices of 3 bytes (21 bits)
- Within these 21 bits, chunk per 6 bits
- Convert these 6 bits to an index (0-63)
- Assign an unique character that can be found at that index in the Base64 table
- Assign an equal sign (`=`) to remaining empty bytes until we reach a multiple of four bytes
- et voila!

**Decoding** is basically working backwards:
- Strip off the padding (`=`)
- Iterate over the remaining byts in chunks of four bytes
- Lookup each ASCII char in the table and get the original index.
- From this index take the upper 6 bits and stitch them back together
- You should end up with a multiple of 8 bits, you've got your original data back.

## Let's get to work!
Ok, enough theory, let's get to work! Let's setup a new Rust project (binary) and implement our first few modules:
```bash
cargo new base64 --bin
```


## Implementing an encoding alphabet
As mentioned previously the default Base64 implementation uses an alphabet containing `A-Z`, `a-z`, `0-9`, `+` and `/`. However I'd like our alphabet to be configurable so you'd be able to supply an Emoji-based alphabet for example 👻

In order to make it configurable, let's come up with a common API that we can implement our configurable alphabets against. Such an API would be described in what Rust calls `traits`. 

### Defining our Alphabet trait

There's pretty much three operations that our alphabet should be able to perform. Going from an index to a character, going from a character back to the original 6-bit index and getting our padding character.

Let's create a new `src/alphabet.rs` file inside our project and let's get going:

```rust
pub trait Alphabet {
    fn get_char_for_index(&self, index: u8) -> Option<char>;
    fn get_index_for_char(&self, character: char) -> Option<u8>;
    fn get_padding_char(&self) -> char;
}
```

### Defining the classic Base64 alphabet
Now that we have a trait describing how an alphabet within our system should look, let's put in the effort to define the classic Base64 alphabet first!

Like we talked about in the beginning of this post, the classic alphabet uses `a-z`, `A-Z`, `0-9` plus `+`, `/` and `=` for padding.

Let's define an empty struct and call it `Classic`, this will act as the type to call the methods on. Let's also supply an implementation for the `Alphabet` trait. Let's place all this into the same `src/alphabet.rs` file for now.

```rust
// ... snip trait declaration

pub struct Classic;

const UPPERCASEOFFSET: i8 = 65;
const LOWERCASEOFFSET: i8 = 71;
const DIGITOFFSET: i8 = -4;

impl Alphabet for Classic {
    fn get_char_for_index(&self, index: u8) -> Option<char> {
        let index = index as i8;

        let ascii_index = match index {
            0..=25 => index + UPPERCASEOFFSET,  // A-Z
            26..=51 => index + LOWERCASEOFFSET, // a-z
            52..=61 => index + DIGITOFFSET,     // 0-9
            62 => 43,                           // +
            63 => 47,                           // /

            _ => return None,
        } as u8;

        Some(ascii_index as char)
    }

    fn get_index_for_char(&self, character: char) -> Option<u8> {
        let character = character as i8;
        let base64_index = match character {
            65..=90 => character - UPPERCASEOFFSET,  // A-Z
            97..=122 => character - LOWERCASEOFFSET, // a-z
            48..=57 => character - DIGITOFFSET,      // 0-9
            43 => 62,                                // +
            47 => 63,                                // /

            _ => return None,
        } as u8;

        Some(base64_index)
    }
}
```

First things first, we define an empty struct called `Classic`. Such a type in Rust-land is called a [zero-sized-type](https://doc.rust-lang.org/nomicon/exotic-sizes.html#zero-sized-types-zsts). Due to the lack of fields, it will only exist in Rusts type system. Once the compiler chewed its way through our source code, there will be no trace of this struct!

Following the struct declaration are a few constants followed by the implementation of the `Alphabet` trait on our `Classic` struct. The implementation itself makes use of the fact that characters in the ASCII alphabet are defined mostly in sequence. For example: `A` through `Z` uppercased have indexes 65 through 90. The same is true for both `a` through `z` lowercased and the digits `0` through `9`. (albeit with different offsets of course :))

We make use of this by pre-calculating an offset between our Base64 index (0-63) and the index in the ASCII alphabet (65-90, 97-122, etc). Then using the `match` operator match on a specific range, apply the correct offset and return the result as a byte. Mission accomplished 💪

## Building the Encoder! 🙌

Now that we have defined how our alphabet should work, let's get to work building the encoder part of our project. Let's define a new module inside `src/encoder.rs`:

```rust
use crate::alphabet::{Alphabet, Classic};
```

First things first, let's bring `Alphabet` (trait) and `Classic` (implementation) into scope and then define a handful of functions that will do the main chunk of the encoding.

### Splitting it up!
Let's start with our split function:

```rust
fn split(chunk: &[u8]) -> Vec<u8> {
    match chunk.len() {
        1 => vec![
            &chunk[0] >> 2,
            (&chunk[0] & 0b00000011) << 4
        ],

        2 => vec![
            &chunk[0] >> 2,
            (&chunk[0] & 0b00000011) << 4 | &chunk[1] >> 4,
            (&chunk[1] & 0b00001111) << 2,
        ],

        3 => vec![
            &chunk[0] >> 2,
            (&chunk[0] & 0b00000011) << 4 | &chunk[1] >> 4,
            (&chunk[1] & 0b00001111) << 2 | &chunk[2] >> 6,
            &chunk[2] & 0b00111111
        ],

        _ => unreachable!()
    }
}
```

Our `split` function takes a slice of bytes (`&[u8]`) and returns a `Vec<u8>`. It converts an input of up-to 3 bytes of input to an output of up-to 4 bytes as output, converting the 8-bit numbers into 6-bit numbers.

> To make this happen we make heavy use of bitwise operations. Depending on the length of the input we're applying different operations. In case of an 1-byte input, we return two bytes where the first 6 bits of the input byte are returned as the first output byte, and the last two bits of the input byte are returned as the second byte. In case of a 3 byte input, we follow the same kind of steps to piece different parts of the bytes together to form 4 output bytes each holding 6 bits of information.

**[__!__] Include graphic of how we split and stitch the bits together**

### Encoding against our Alphabet
Now that we have a mechanism to convert from 8-bit numbers to 6-bit numbers, let's chunk the original data into 3-byte portions and run them through our split functions.

```rust
pub fn encode_using_alphabet<T: Alphabet>(alphabet: &T, data: &[u8]) -> String {
    let encoded = data
        .chunks(3)
        .map(split)
        .flat_map(|chunk| encode_chunk(alphabet, chunk));

    String::from_iter(encoded)
}
```
Let's define a `encode_with_alphabet` function that takes an alphabet to encode against and the original data to perform the encoding on. 

The first step is chunking the data into 3-byte portions then feeding it into our split function we've defined previously. Knowing that this will return a `Vec<u8>`, we can pass this through `flat_map` running each chunk of four bytes through `encode_chunk` that does the actual lookup in the provided alphabet for us. 

Lastly we pass the iterator that ultimately returns a `Vec<char>` to `String::from_iter` which will consume our iterator char-by-char to exhaustion and form a String. For that to work though, we bring the `FromIterator` into scope, see:

```rust
use std::iter::FromIterator;
```

### Encoding chunk by chunk
Now back to our `encode_chunk` function:

```rust
fn encode_chunk<T: Alphabet>(alphabet: &T, chunk: Vec<u8>) -> Vec<char> {
    let mut out = vec![alphabet.get_padding_char(); 4];

    for i in 0..chunk.len() {
        if let Some(chr) = alphabet.get_char_for_index(chunk[i]) {
            out[i] = chr;
        }
    }

    out
}
```

This function starts off by defining a `Vec<char>` holding four padding chars in case we run out of actual data to write. Note we tag the `out` variable as mutable as we're going to overwrite the positions that do hold actual data within our loop.

Inside our loop we take the 6-bit number, do a lookup against our passed in Alphabet and replace the padding symbol with the actual data, if available.

That's it! That's all there is to do to get your data Base64 encoded! I wont bore you with the tests but for those interested, [check em out on the repo](https://github.com/Tmw/base64-rs/blob/master/src/decoder.rs#L64-L87)

## Decoding
Now that we can turn any arbitrary binary blob into a easy-to-transmit Base64 string, we obviously want to retrieve our original data from the encoded blob, otherwise we just built a data corrupter ;)

Let's implement our decoder in a separate module in `src/decoder.rs`. Much like with our encoder we're going to need our _Alphabet_ trait together with our _Classic_ implementation. Let's bring these into scope, like so:

```rust
use crate::alphabet::{Alphabet, Classic};
```

Let's dive right in and define a `decode_using_alpabet` function that, much like our `encode_using_alphabet` function takes the alphabet to do the decoding against and the encoded stirng to perform the decoding on.

```rust
pub fn decode_using_alphabet<T: Alphabet>(alphabet: T, data: &String) -> Vec<u8> {
    // if data is not multiple of four bytes, data is invalid
    if data.chars().count() % 4 != 0 {
        panic!("Invalid data");
    }

    data
        .chars()
        .collect::<Vec<char>>()
        .chunks(4)
        .map(|chunk| original(&alphabet, chunk) )
        .flat_map(stitch)
        .collect()
}
```

The first thing we do is throw an error if the supplied data does not have the length that is a multiple of four. We know that in a Base64 encoded string, we will always end up with a multiple of four bytes, if needed filled up with padding symbols. If this is simply not the case, disregard the input as corrupt and early exit our program.

However if we did receive a multiple of four characters, we split the string into its `chars` in chunks of four chars each and feed the chunks to the `original` function where we're fetching the original 6-bit number from our alphabet. This chunk goes into the `stitch` function to convert back into original data.

Let's take a look at our `original` function first:

```rust
fn original<T: Alphabet>(alphabet: &T, chunk: &[char]) -> Vec<u8> {
    chunk
        .iter()
        .filter(|character| *character != &alphabet.get_padding_char())
        .map(|character| { 
            alphabet
                .get_index_for_char(*character)
                .expect("unable to find character in alphabet")
        })
        .collect()
}
```

It takes the alphabet again and a slice of chars (up-to four of 'em) and it returns a `Vec<u8>`. The function pretty much iterates over the characters in the slice, ignores them once they're padding characters and otherwise looks up their original index in the alphabet.

### Stitch it back up
The last function of that chain, `stitch`, takes a `Vec<u8>` and returns a `Vec<u8>` and in the middle it does pretty much the opposite of the `split` function we saw earlier:

```rust
fn stitch(bytes: Vec<u8>) -> Vec<u8> {
    let out = match bytes.len() {
        2 => vec![
            (bytes[0] & 0b00111111) << 2 | bytes[1] >> 4,
            (bytes[1] & 0b00001111) << 4,
        ],

        3 => vec![
            (bytes[0] & 0b00111111) << 2 | bytes[1] >> 4,
            (bytes[1] & 0b00001111) << 4 | bytes[2] >> 2,
            (bytes[2] & 0b00000011) << 6,
        ],

        4 => vec![
            (bytes[0] & 0b00111111) << 2 | bytes[1] >> 4,
            (bytes[1] & 0b00001111) << 4 | bytes[2] >> 2,
            (bytes[2] & 0b00000011) << 6 | bytes[3] & 0b00111111,
        ],

        _ => unimplemented!("number of bytes must be 2 - 4")
    };

    out.into_iter().filter(|&x| x > 0).collect()
}
```

Once again, depending on the input length, we're applying some bitwise operations to convert the chunk of four bytes down to 3, converting our four 6-bit numbers back into three 8-bit numbers.

**TODO** Add a nice illustration here again

And voila, this should be the whole decoder. Obviously this module should [include some tests too](https://github.com/Tmw/base64-rs/blob/master/src/decoder.rs#L60:L84) ✨✨



## Piecing it together

** TODO** Perhaps nice little illustration here too
Notice that we wrote all these pieces but our `fn main()` still has the placeholder `println!("hello, world!");` in it? Let's change that so that we can compile our binary into something useful: a command line application that actually takes binary data and converts it to Base64 and vice versa!

TODO   But we still need to write that code too. I'll do that after finalising the pieces of the library :)

This also includes pulling in all the modules (`mod ...`) inside `main.rs`.
