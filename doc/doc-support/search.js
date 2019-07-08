window.onload = function() {
    surround = document.createElement("div");
    surround.innerHTML = `
    <div id='searchstatus'>LOADING...</div>
    <form>
      <input type='search' onkeyup='dosort(this.value);' />
    </form>
    <h2>search results for <tt id='searchterm'>(nothing)</tt></h2>
    <div id='searchresult'></div>
    <div class='navheader'>`;
    document.getElementsByTagName("body")[0].prepend(surround);

fetch("index.json")
    .then(response => response.json())
    .then(v => window.index = elasticlunr.Index.load(v))
    .then(v => document.getElementById("searchstatus").innerText = "Ready!")
/*index = elasticlunr.Index.load(window.v)*/

}

function removeChildren(elem) {
    while (elem.firstChild) {
        elem.removeChild(elem.firstChild);
    }
}

function dosort(term) {
    searchresults = document.getElementById("searchresult")
    searchterm = document.getElementById("searchterm")
    result = window.index.search(term);
    removeChildren(searchresults);
    for(var i = 0; i < result.length ; i++){
        var resultElem = document.createElement('li');
        resultElem.innerHTML = '<a href="' + result[i].ref + '">' + result[i].doc.title + '</a>' +
            '<p>' + makeTeaser(result[i].doc.body, term.split(' ')) + '</p>';

        searchresults.appendChild(resultElem);
    }
    searchterm.innerText = term;
}

// lifted from rust-lang-nursery/mdBook 84d4063e4a60f0b0fc2058b9f100f91244d60f99
// (MPL-2.0)
function makeTeaser(body, searchterms) {
    //
    results_options = {
        teaser_word_count: 30,
    };

        // The strategy is as follows:
        // First, assign a value to each word in the document:
        //  Words that correspond to search terms (stemmer aware): 40
        //  Normal words: 2
        //  First word in a sentence: 8
        // Then use a sliding window with a constant number of words and count the
        // sum of the values of the words within the window. Then use the window that got the
        // maximum sum. If there are multiple maximas, then get the last one.
        // Enclose the terms in <em>.
        var stemmed_searchterms = searchterms.map(function(w) {
            return elasticlunr.stemmer(w.toLowerCase());
        });
        var searchterm_weight = 40;
        var weighted = []; // contains elements of ["word", weight, index_in_document]
        // split in sentences, then words
        var sentences = body.toLowerCase().split('. ');
        var index = 0;
        var value = 0;
        var searchterm_found = false;
        for (var sentenceindex in sentences) {
            var words = sentences[sentenceindex].split(' ');
            value = 8;
            for (var wordindex in words) {
                var word = words[wordindex];
                if (word.length > 0) {
                    for (var searchtermindex in stemmed_searchterms) {
                        if (elasticlunr.stemmer(word).startsWith(stemmed_searchterms[searchtermindex])) {
                            value = searchterm_weight;
                            searchterm_found = true;
                        }
                    };
                    weighted.push([word, value, index]);
                    value = 2;
                }
                index += word.length;
                index += 1; // ' ' or '.' if last word in sentence
            };
            index += 1; // because we split at a two-char boundary '. '
        };

        if (weighted.length == 0) {
            return body;
        }

        var window_weight = [];
        var window_size = Math.min(weighted.length, results_options.teaser_word_count);

        var cur_sum = 0;
        for (var wordindex = 0; wordindex < window_size; wordindex++) {
            cur_sum += weighted[wordindex][1];
        };
        window_weight.push(cur_sum);
        for (var wordindex = 0; wordindex < weighted.length - window_size; wordindex++) {
            cur_sum -= weighted[wordindex][1];
            cur_sum += weighted[wordindex + window_size][1];
            window_weight.push(cur_sum);
        };

        if (searchterm_found) {
            var max_sum = 0;
            var max_sum_window_index = 0;
            // backwards
            for (var i = window_weight.length - 1; i >= 0; i--) {
                if (window_weight[i] > max_sum) {
                    max_sum = window_weight[i];
                    max_sum_window_index = i;
                }
            };
        } else {
            max_sum_window_index = 0;
        }

        // add <em/> around searchterms
        var teaser_split = [];
        var index = weighted[max_sum_window_index][2];
        for (var i = max_sum_window_index; i < max_sum_window_index+window_size; i++) {
            var word = weighted[i];
            if (index < word[2]) {
                // missing text from index to start of `word`
                teaser_split.push(body.substring(index, word[2]));
                index = word[2];
            }
            if (word[1] == searchterm_weight) {
                teaser_split.push("<em>")
            }
            index = word[2] + word[0].length;
            teaser_split.push(body.substring(word[2], index));
            if (word[1] == searchterm_weight) {
                teaser_split.push("</em>")
            }
        };

        return teaser_split.join('');
    }
