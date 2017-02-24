# Ride-Sharing
A MVP of a ride sharing app, like Uber of Lyft.

Could someone make their own minimally viable version of Uber or Lyft in a weekend? **You bet they can.** 

Lyft and Uber are worth millions of dollars but the concept behind their, and other ride sharing apps is, in many ways quite simple. That’s part of it’s power. As an absolute minimum viable product (MVP), there is nothing too technologically challenging behind ride-sharing apps. I often told friends and colleagues that, if someone wanted to, they could make their own ride sharing app in just a weekend. I decided to call myself out on that claim. And this is the working result. The core technology is under 1500 lines of code.

# Brief Summary <br />
As a passenger, you can request a pickup from drivers near you.
As a driver, wait for nearby passengers to request rides. For every pickup request, each nearby rider has the option to “accept” the pickup or “pass” the opportunity.
This single app contains both the passenger and driver mode. It works; but is also a work in progress.


# Technical Discussion
I built this app without a custom backend. I’m generalizing, but many ride-sharing apps use a comparatively simple client app that communicates with a complex backend (Figure 1). My idea is to reverse this paradigm: with a complex client app powered by a comparatively simple backend (Figure 2).

My simple backend is akin to a messaging board, it is the way for the drivers and passengers to pass messages; with all the complex processing taking place on the client app.

In a typical ride sharing app, when a passenger requests a pickup, that request goes to the server and that server is tasked with finding nearby drivers and pinging each one in turn to see if they accept the pickup request. In my app, the App itself:
1. Looks for nearby drivers by consulting a simple list of available drivers.
2. Finds the nearest driver.
3. Posts a pickup request in that driver’s directory.

The driver’s app is monitoring that request directory and gives the driver several seconds to respond to that pickup request. If that driver does not respond in time, or decides to “pass” on the pickup, the passenger app then finds the next nearest driver and posts the same request in that driver’s request directory. That process continues until a driver is found or all nearby drivers “pass”. See figure 3 for a detailed diagram of this interaction. 

Smartphones are incredibly powerful; instead of building a custom cloud backend, why not use an off-the-shelf backend and the phones themselves to handle the complex precessing? By having client apps do the heavy lifting, the App can scale quickly and precisely, in proportion with the number of users.

This simplified backend approach, of course, still requires a backend, and Google’s Firebase is uniquely suited to the task. With Firebase, the client app listens for changes in specified directories and is instantly notified of changes, such as a driver receiving a pickup request. This way, the client app does not periodically query the server for updates, updates are automatically pushed to the client app as needed. This minimizes the number of server calls / reduces network activity.


# Potential Drawbacks and Solutions

No system architecture is perfect, particularly architectures based on absolutes. For example:
- A ride sharing app that is pure backend would really struggle in low connectivity and high latency environments.
- On the other hand, finding drivers on a ride sharing app that completely lacks a backend would rely on ad-hoc networking via bluetooth and/or wifi. It would be incredibly short range and really hard to gather analytics from.

There are always pros and cons for every approach. The goal should be to take the best from each architecture and combine them in a way that delights users and is totally transparent to them. This experimental app highlights some of the architectural tradeoffs.

## Major Drawback

The biggest change with this App’s approach is caused by version fragmentation. By preforming the complex processing on the client app, it is harder to change how these processes work, unless the user updates their app to the latest version. For example, if you wanted to change the algorithm that determines the “nearest driver” by increasing the importance of “star rating” at the expense of the driver’s distance, you need to push a new app update to all clients, for that change to take effect.

The fantastic advantage of the complex server is that changes can be made and immediately pushed to all clients simultaneously. This ensures that all clients have the same refined user experience. In contrast, the user experience in my approach is dependent on all users updating the App on their devices. Assuming that all users update their app (which is not a reasonable assumption) it will take several days to deploy algorithmic changes, at best. But many users don’t update their apps, so they would never get those changes.

How do you still allow up-updated users to participate in the App even if the underlying algorithms have changed? Do you silo user bases with different versions? In that scenario, all drivers and passengers who continue to use, say the December 2016 version of the App, can continue to use the App with other un-updated users. Or do you create an inconvenient alert telling users to update the App before attempting to use it?

## Potential Solutions 
One possible solution is to create server variables for the aspects of the App most likely to change. For example, drivers are each given 10 seconds to decide whether to accept the passenger pickup request or “pass”. That 10 seconds can be a variable that lives on the server, and the backend silently notifies client apps when that number is changed, say to 20 seconds.

It would be fascinating to see a pie-graph breakdown of app versions for the major ride sharing companies. What percentage of their user base is on the latest version and what percentage is still using versions from months ago? Those percentages likely to vary depending on the platform; given the currently larger OS fragmentation on Android, iOS users are more likely to be more updated. But that may be a moot pint: clients of major ride-sharing apps may have a higher propensity to “stay current” with app updates compared to other platform users. It is interesting to note that in December 2016, Uber updated their app four times and Lyft updated their app three times. Regardless of the ability to make changes on the backend, it is clearly still necessary to update the client app often.


<br /><br /><br /><br />
# Image Credits

1.
Driver Icon used under the GNU General Public License
By Elegantthemes
At: http://www.iconarchive.com/show/beautiful-flat-one-color-icons-by-elegantthemes/car-icon.html

2.
App Icon used with permission under the creative commons 3.0 license.
“clean car” by Gregor Cresnar from the Noun Project.
Modified by inverting original colors.

<br /><br />
# Notice

Uber is a trademark of Uber Technologies. 
Lyft is a trademark of Lyft Inc.

This code is not a product, service or business offering of any sort.

Thanks to the ubiquitousness of their service, I simply use the terms “Uber” and “Lyft” to help describe some of what my code does. I am in no way affiliated with Uber Technologies or Lyft Inc. I claim no ownership of their trademarked, patented, proprietary or trade secret technologies. They have not endorsed my usage of their trademarks to help describe what this code does. Like Xerox, Google and Kleenex, these companies have created such great products that they have entered the average lexicon. If there are any problems with my usage, I’m more than happy to change it. Thank you for your understanding.
