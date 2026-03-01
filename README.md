<p style="text-align:center"><a href=https://github.com/Sverdlovsky/open-media-hub/README.md>English</a> | <a href=https://github.com/Sverdlovsky/open-media-hub/README.ru.md>Русский</a></p>

# Open Media Hub

A web resource for watching TV series online via [MPV](https://mpv.io/) and learning languages. Viewing with authorization allows you to save the number of episodes watched and changes the appearance of the cards depending on your progress. Language learning takes place through an intelligent mechanism that displays words taken directly from the TV series being watched by the user.

## Features

- **External player:** Using an external player eliminates the main drawback of traditional browser players — low video quality due to an extremely limited list of supported codecs. The external player supports all the latest codecs, which allows you to significantly reduce the size of the transmitted file to save traffic and improve the final image quality after compression. MPV also supports shaders, including upscale, which allows you to watch any series in 4K.
- **User account:** Login is via OAuth 2.0, which simplifies account creation and login, while allowing you to maintain user privacy by storing only their email and display name. Having an account also allows you to keep track of the episodes you've watched and update the appearance of the series cards as you progress through the plot.
- **Learning useful words:** You can choose a pool of words, whether it's the entire series or a specific episode. You can also study the most frequent words among all the series available in the database.
- **Intelligent word selection system:** The media resource uses an Anki-like flashcard learning system. Unlike Anki, the cards do not have a fixed position in the queue, but are selected based on the applicability of the word, the degree to which it has been learned, and the user's personal learning speed. This creates a flexible system that allows you to learn words at your own pace, balancing between the quality and quantity of words learned. 

## Technologies

- **Svelte:** The entire frontend is written in Svelte. It is a convenient and modern framework that combines reactivity and speed.
- **Rust:** The service API is implemented in Rust. It is a modern, fast, and secure multi-purpose programming language. It handles authorization and isolates the user from the database.
- **Python:** Implements communication with external services for OAuth 2.0.
- **PostgreSQL:** A database that stores all information. It also implements word selection during training and generates JSON API responses.
- **Nginx:** Delivers static data, including Svelte-generated pages. It processes Range requests when delivering videos.

## How does it work?

To start watching, simply click on the series poster, which will automatically open a pre-prepared franchise playlist in MPV. Authorization also allows you to save the episode number to continue watching in the future. Authorization can be performed through any external service that supports OAuth 2.0.

Unlike Anki, learning involves completing a continuous course. This does not mean that the entire course must be completed in one attempt — you can stop after each card, and this will not affect the selection of future cards.

When selecting the next card, priority is given to words from the selected pool. The following factors are taken into account when calculating priority:

- The “proficiency” of the word, which consists of:
  - the old “proficiency” value
  - the confidence coefficient (the more times the word is displayed, the higher the coefficient)
  - the time of the last response
- The “usefulness” coefficient
- The age of the last display

The “learning” of a word is a key indicator that reflects the user's realistic degree of memorization of a particular word. To calculate it, the user's response time and the previous value of the indicator are taken into account. A confidence coefficient is applied to the result to reduce the rate of increase in value when there are frequent correct responses. Thus, well-learned words will still appear periodically until the coefficient increases.

The “usefulness” coefficient is a mechanism that pushes “useless” words to the end of the queue. Words are considered “useless” if the user has given too many positive or negative answers. The purpose of excluding “difficult” words is to reduce user frustration in order to decrease the likelihood of them quitting the learning process, as well as to use the freed-up time to learn new or more useful words.

Thus, the algorithms used allow you to learn the maximum number of words in the shortest possible time for the quickest transition to practice, which helps to consolidate what you have learned and compensates for the shortcomings of “superficial” learning.

