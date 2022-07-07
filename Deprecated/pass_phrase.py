#!/usr/bin/env python
# encoding: utf-8

## leaving this here for reference. I no longer use this file due to Python not being included with Mac OS starting with 12.3

### I DID NOT WRITE THIS FILE! SEE LICENSE! I AM PUTTING HERE SO IT CAN BE REFERENCE TO OTHER USERS.

import random
import optparse
import sys
import re
import os
import math
import datetime
import string

__LICENSE__ = """
The MIT License (MIT)

Copyright (c) 2012 Aaron Bassett, http://aaronbassett.com

Permission is hereby granted, free of charge, to any person 
obtaining a copy of this software and associated documentation 
files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, 
merge, publish, distribute, sublicense, and/or sell copies of the 
Software, and to permit persons to whom the Software is furnished 
to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be 
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, 
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR 
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
"""

# random.SystemRandom() should be cryptographically secure
try:
    rng = random.SystemRandom
except AttributeError:
    sys.stderr.write("WARNING: System does not support cryptographically "
                     "secure random number generator or you are using Python "
                     "version < 2.4.\n"
                     "Continuing with less-secure generator.\n")
    rng = random.Random


# Python 3 compatibility
if sys.version[0] == "3":
    raw_input = input


def validate_options(options, args):
    """
    Given a set of command line options, performs various validation checks
    """
    
    if options.num <= 0:
        sys.stderr.write("Little point running the script if you "
                         "don't generate even a single passphrase.\n")
        sys.exit(1)

    if options.max_length < options.min_length:
        sys.stderr.write("The maximum length of a word can not be "
                         "lesser then minimum length.\n"
                         "Check the specified settings.\n")
        sys.exit(1)

    if len(args) >= 1:
        parser.error("Too many arguments.")

    for word_type in ["adjectives", "nouns", "verbs"]:
        wordfile = getattr(options, word_type, None)
        if wordfile is not None:
            if not os.path.exists(os.path.abspath(wordfile)):
                sys.stderr.write("Could not open the specified {0} word file.\n".format(word_type))
                sys.exit(1)
        else:
            common_word_file_locations = ["{0}.txt", "~/.pass-phrase/{0}.txt"]

            for loc in common_word_file_locations:
                wordfile = loc.format(word_type)
                if os.path.exists(wordfile):
                    setattr(options, word_type, wordfile)
                    break

        if getattr(options, word_type, None) is None:
            sys.stderr.write("Could not find {0} word file, or word file does not exist.\n".format(word_type))
            sys.exit(1)


def leet(word):
    geek_letters = {
        "a": ["4", "@"],
        "b": ["8",],
        "c": ["(",],
        "e": ["3",],
        "f": ["ph", "pH"],
        "g": ["9", "6"],
        "h": ["#",],
        "i": ["1", "!", "|"],
        "l": ["!", "|"],
        "o": ["0", "()"],
        "q": ["kw",],
        "s": ["5", "$"],
        "t": ["7",],
        "x": ["><",],
        "y": ["j",],
        "z": ["2",]
    }
    
    geek_word = ""
    
    for letter in word:
        l = letter.lower()
        if l in geek_letters:
            # swap out the letter *most* (80%) of the time
            if rng().randint(1,5) % 5 != 0:
                letter = rng().choice(geek_letters[l])
        else:
            # uppercase it *some* (10%) of the time
            if rng().randint(1,10) % 10 != 0:
                letter = letter.upper()
        
        geek_word += letter
    
    # if last letter is an S swap it out half the time
    if word[-1:].lower() == "s" and rng().randint(1,2) % 2 == 0:
        geek_word = geek_word[:-1] + "zz"
    
    return geek_word
    

def mini_leet(word):
    geek_letters = {
        "a": "4",
        "b": "8",
        "e": "3",
        "g": "6",
        "i": "1",
        "o": "0",
        "s": "5",
        "t": "7",
        "z": "2",
    }
    
    geek_word = ""
    
    for letter in word:
        l = letter.lower()
        if l in geek_letters:
            letter = geek_letters[l]
        
        geek_word += letter
    
    return geek_word


def generate_wordlist(wordfile=None,
                      min_length=0,
                      max_length=20,
                      valid_chars='.',
                      make_leet=False,
                      make_mini_leet=False):
    """
    Generate a word list from either a kwarg wordfile, or a system default
    valid_chars is a regular expression match condition (default - all chars)
    """

    words = []

    regexp = re.compile("^%s{%i,%i}$" % (valid_chars, min_length, max_length))

    # At this point wordfile is set
    wordfile = os.path.expanduser(wordfile)  # just to be sure
    wlf = open(wordfile)

    for line in wlf:
        thisword = line.strip()
        if regexp.match(thisword) is not None:
            if make_mini_leet:
                thisword = mini_leet(thisword)
            elif make_leet:
                thisword = leet(thisword)

            words.append(thisword)

    wlf.close()
    
    if len(words) < 1:
        sys.stderr.write("Could not get enough words!\n")
        sys.stderr.write("This could be a result of either {0} being too small,\n".format(wordfile))
        sys.stderr.write("or your settings too strict.\n")
        sys.exit(1)

    return words
    

def craking_time(seconds):
    minute = 60
    hour = minute * 60
    day = hour * 24
    week = day * 7
    
    if seconds < 60:
        return "less than a minute"
    elif seconds < 60 * 5:
        return "less than 5 minutes"
    elif seconds < 60 * 10:
        return "less than 10 minutes"
    elif seconds < 60 * 60:
        return "less than an hour"
    elif seconds < 60 * 60 * 24:
        hours, r = divmod(seconds, 60 * 60)
        return "about %i hours" % hours
    elif seconds < 60 * 60 * 24 * 14:
        days, r = divmod(seconds, 60 * 60 * 24)
        return "about %i days" % days
    elif seconds < 60 * 60 * 24 * 7 * 8:
        weeks, r = divmod(seconds, 60 * 60 * 24 * 7)
        return "about %i weeks" % weeks
    elif seconds < 60 * 60 * 24 * 365 * 2:
        months, r = divmod(seconds, 60 * 60 * 24 * 7 * 4)
        return "about %i months" % months
    else:
        years, r = divmod(seconds, 60 * 60 * 24 * 365)
        return "about %i years" % years


def verbose_reports(**kwargs):
    """
    Report entropy metrics based on word list size"
    """
    
    options = kwargs.pop("options")
    f = {}

    for word_type in ["adjectives", "nouns", "verbs"]:
        print("The supplied {word_type} list is located at {loc}.".format(
            word_type=word_type,
            loc=os.path.abspath(getattr(options, word_type))
        ))
        
        words = kwargs[word_type]
        f[word_type] = {}
        f[word_type]["length"] = len(words)
        f[word_type]["bits"] = math.log(f[word_type]["length"], 2)

        if (int(f[word_type]["bits"]) == f[word_type]["bits"]):
            print("Your %s word list contains %i words, or 2^%i words."
                  % (word_type, f[word_type]["length"], f[word_type]["bits"]))
        else:
            print("Your %s word list contains %i words, or 2^%0.2f words."
                  % (word_type, f[word_type]["length"], f[word_type]["bits"]))
    
    entropy = f["adjectives"]["bits"] +\
              f["nouns"]["bits"] +\
              f["verbs"]["bits"] +\
              f["adjectives"]["bits"] +\
              f["nouns"]["bits"]
    
    print("A passphrase from this list will have roughly "
          "%i (%0.2f + %0.2f + %0.2f + %0.2f + %0.2f) bits of entropy, " % (
              entropy,
              f["adjectives"]["bits"],
              f["nouns"]["bits"],
              f["verbs"]["bits"],
              f["adjectives"]["bits"],
              f["nouns"]["bits"]
          ))

    combinations = math.pow(2, int(entropy)) / 1000
    time_taken = craking_time(combinations)
    
    print("Estimated time to crack this passphrase (at 1,000 guesses per second): %s\n" % time_taken)

def generate_passphrase(adjectives, nouns, verbs, separator):
    return "{0}{s}{1}{s}{2}{s}{3}{s}{4}".format(
        rng().choice(adjectives),
        rng().choice(nouns),
        rng().choice(verbs),
        rng().choice(adjectives),
        rng().choice(nouns),
        s=separator
    )


def passphrase(adjectives, nouns, verbs, separator, num=1,
               uppercase=False, lowercase=False, capitalise=False):
    """
    Returns a random pass-phrase made up of
    adjective noun verb adjective noun
    
    I find this basic structure easier to 
    remember than XKCD style purely random words
    """
    
    phrases = []

    for i in range(0, num):
        phrase = generate_passphrase(adjectives, nouns, verbs, separator)
        if capitalise:
            phrase = string.capwords(phrase)
        phrases.append(phrase)

    all_phrases = "\n".join(phrases)
    
    if uppercase:
        all_phrases = all_phrases.upper()
    elif lowercase:
        all_phrases = all_phrases.lower()
        
    return all_phrases


if __name__ == "__main__":

    usage = "usage: %prog [options]"
    parser = optparse.OptionParser(usage)
    
    parser.add_option("--adjectives", dest="adjectives",
                      default=None,
                      help="List of valid adjectives for passphrase")
                      
    parser.add_option("--nouns", dest="nouns",
                      default=None,
                      help="List of valid nouns for passphrase")
                      
    parser.add_option("--verbs", dest="verbs",
                      default=None,
                      help="List of valid verbs for passphrase")
    
    parser.add_option("-s", "--separator", dest="separator",
                      default=' ',
                      help="Separator to add between words")
                      
    parser.add_option("-n", "--num", dest="num",
                      default=1, type="int",
                      help="Number of passphrases to generate")
                      
    parser.add_option("--min", dest="min_length",
                      default=0, type="int",
                      help="Minimum length of a valid word to use in passphrase")
                      
    parser.add_option("--max", dest="max_length",
                      default=20, type="int",
                      help="Maximum length of a valid word to use in passphrase")
                      
    parser.add_option("--valid_chars", dest="valid_chars",
                      default='.',
                      help="Valid chars, using regexp style (e.g. '[a-z]')")
    
    parser.add_option("-U", "--uppercase", dest="uppercase",
                      default=False, action="store_true",
                      help="Force passphrase into uppercase")
    
    parser.add_option("-L", "--lowercase", dest="lowercase",
                      default=False, action="store_true",
                      help="Force passphrase into lowercase")
    
    parser.add_option("-C", "--capitalise", "--capitalize", dest="capitalise",
                      default=False, action="store_true",
                      help="Force passphrase to capitalise each word")
    
    parser.add_option("--l337", dest="make_leet",
                      default=False, action="store_true",
                      help="7#izz R3@l|j !$ 4941Nst 7#3 w#()|e 5P|R!7 0pH t#3 7#|N6.")
                      
    parser.add_option("--l337ish", dest="make_mini_leet",
                      default=False, action="store_true",
                      help="A l337 version which is easier to remember.")

    parser.add_option("-V", "--verbose", dest="verbose",
                      default=False, action="store_true",
                      help="Report various metrics for given options")
    
    (options, args) = parser.parse_args()
    validate_options(options, args)
    
    # Generate word lists
    adjectives = generate_wordlist(wordfile=options.adjectives,
                              min_length=options.min_length,
                              max_length=options.max_length,
                              valid_chars=options.valid_chars,
                              make_mini_leet=options.make_mini_leet,
                              make_leet=options.make_leet)
    
    nouns = generate_wordlist(wordfile=options.nouns,
                              min_length=options.min_length,
                              max_length=options.max_length,
                              valid_chars=options.valid_chars,
                              make_mini_leet=options.make_mini_leet,
                              make_leet=options.make_leet)
    
    verbs = generate_wordlist(wordfile=options.verbs,
                              min_length=options.min_length,
                              max_length=options.max_length,
                              valid_chars=options.valid_chars,
                              make_mini_leet=options.make_mini_leet,
                              make_leet=options.make_leet)
    
    if options.verbose:
        verbose_reports(adjectives=adjectives,
                        nouns=nouns,
                        verbs=verbs,
                        options=options)
    
    print(passphrase(
            adjectives,
            nouns,
            verbs,
            options.separator,
            num=int(options.num),
            uppercase=options.uppercase,
            lowercase=options.lowercase,
            capitalise=options.capitalise
        )
    )
