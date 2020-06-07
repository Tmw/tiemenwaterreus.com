---
title: "Linear Regression with Elixir, Phoenix and LiveView. Part II"
date: 2020-05-09T22:30:03+02:00
draft: false
keywords: linrear regression, machine learning, elixir, liveview
description: Making our linear regression algorithm interactive using Phoenix LiveView
icon: 📈
---

In the [previous post](/posts/linear-regression-elixir-phoenix-liveview-i/) we walked through setting up a fairly simple linear regression algorithm that uses the slope-intercept form and gradient descent to fit the best line possible over a list of given datapoints. In this part we will make this interactive using Phoenix LiveView and a SVG element in the browser.

## Kicking things off

In the previous post we've scaffolded a Phoenix LiveView application using `mix phx.new --live --no-ecto` but up until now we only focused on the non-phoenix parts. Let's begin by starting our development server and see what we're setup with out-of-the-box:

Either `iex -S mix phx.server` or `mix phoenix.server` will do. I like the former better because it drops us immediately into an IEx session we can use to inspect, validate or just doodle around.

Visiting `http://localhost:4000` will greet us with a default Phoenix LiveView page:

{{< figure src="/resources/linreg-ii/default_page.png" caption="The default Phoenix LiveView page" >}}

Now open your favorite editor and look under `lib/linreg_web/live`. This is where the LiveView modules and their templates live. Go ahead and add two files to this folder: `regression_live.ex` and `regression_live.html.leex`.

## Setting up the LiveView module and its template

Now that we have a new module for our logic, go ahead and open the `regression_live.ex` file to start coding our module.

```elixir
defmodule LinregWeb.RegressionLive do
  use LinregWeb, :live_view

  @impl true
  def mount(_params, _sesion, socket) do
    {:ok, socket}
  end
end
```

This is the most barebones version of a LiveView module we can write. It defines a new module called `RegressionLive` which uses the LiveView parts of our application. Its behaviour specifies only one required function `mount/3` to kick things off. It knows, by convention, to render the `regression_live.html.leex` template.

Now, to actually show something in the browser, we'll need to write some HTML. Open the template file `regression_live.html.leex` and add some basic HTML:

```html
<h1>Hello, LiveView!</h1>
```

And lastly, in order to be able to view it, we need to hook the LiveView module up to our router. Locate the `router.ex` file living in `lib/linreg_web/` and find the line where it says:

```elixir
live "/", PageLive, :index
```

This line tells Phoenix to mount the LiveView module on the root route ("/"), hook it up to the PageLive module and mark it as the `:index` action.In other words, if there's a request made to our root route, we'll render the `PageLive` live module.

We want to change that to our own module and see our friendly greeting:

```elixir
live "/", RegressionLive, :index
```

Now refresh our browser and be greeted with our own module:

{{< figure src="/resources/linreg-ii/hello_liveview.png" caption="Our own Linreg.RegressionLive module in effect!" >}}

## Collecting datapoints

Now that we have a basic LiveView setup, we can start working on collecting datapoints to let our model learn against. Let's begin by rendering a SVG plane on screen.

Open our live template (`regression_live.html.leex`) and write the following code:

```html
<svg phx-click="add_point" width="800" height="800"></svg>
```

This sets up an empty SVG element with a with and height of 800px. Another important thing that we've added here is the `phx-click` attribute. This is the LiveView magic that will make it interactive! This ties an event listener to this element that will react to click events on the SVG element and will send off an event called `add_point`.

Let's setup the eventhandler itself. Open up the `regression_live.ex` module again and write the following function in there:

```elixir
@impl true
def handle_event("add_point", params, socket) do
  IO.inspect(params, label: "params")
  {:noreply, socket}
end
```

The function definition above has three parameters. The first one is the event name, followed by the parameters of that event and lastly the socket which holds our state and causes the template to re-render if anything changes.

All this function does is print out the parameters when the `"add_point"` event comes in. Let's try it out by refreshing the page and clicking anywhere on the SVG element. The terminal running your Phoenix app should now show something along the lines of:

```bash
params: %{
  "altKey" => false,
  "ctrlKey" => false,
  "detail" => 1,
  "metaKey" => false,
  "offsetX" => 549,
  "offsetY" => 227,
  "pageX" => 832,
  "pageY" => 367,
  "screenX" => 832,
  "screenY" => 465,
  "shiftKey" => false,
  "x" => 832,
  "y" => 367
}
```

It's right there in the `offsetX` and `offsetY` where we get our coordinates within the SVG.

Note: Since Phoenix 1.5.3 and Phoenix LiveView 0.13.0 `phx-click` no longer sends its metadata along. See the troubleshooting section on Github on [how to fix this](https://github.com/tmw/linreg/#clicks-not-appearing).


## Scaling the data

The coordinates that will come in will be between 0 and 800. Our linear regression algorithm works better with smaller numbers. To make this work we'll need to scale our coordinates down to between 0 and 1. I've added a convenience function called `map/5` that takes the original value alongside its original scale and maps it to the second given scale. For example:

```elixir
map(5, 0, 10, 0, 1) # 0.5
```

I've wrote this function in the module `linreg/math.ex` so we can use it both in our Live module to scale the coordinates down as well as in our template to scale the coordinates back up to their original.

```elixir
defmodule Linreg.Math do
  def map(value, in_min, in_max, out_min, out_max) do
    out_min + (out_max - out_min) * ((value - in_min) / (in_max - in_min))
  end
end
```

Then I imported the module into our `lib/linreg_web.ex` module under `view_helpers/0`:

```diff
defp view_helpers do
  quote do
    # Use all HTML functionality (forms, tags, etc)
    use Phoenix.HTML
    #... snip


    alias LinregWeb.Router.Helpers, as: Routes

+   import Linreg.Math, only: [map: 5]
  end
end
```

Importing it in our view_helpers will make it available in both our `_live` modules as well as our `.leex` templates, which are exactly the places where we'll need them.

## Adding points to our training data

Head back to our `regression_live.ex` module and find the `mount/3` function. This function is executed once (upon hitting the route). This is also the place where we can assign an initial state to our socket. Let's use this hook to initialize an empty model and an empty data struct to collect our datapoints in, like so:

```elixir
def mount(_params, _sesion, socket) do
  socket =
    socket
    |> assign(model: Linreg.Model.new())
    |> assign(data: Linreg.Data.new())

  {:ok, socket}
end
```

Now in every handler where we have access to the socket, we also have access to this state in the `assigns` map. For the next step, we need to go back to our `handle_event/3` function and add some logic in and around that function:

```elixir
  def handle_event("add_point", params, socket) do
    {:noreply, add_point(params, socket)}
  end

  defp add_point(%{"offsetX" => x, "offsetY" => y}, socket) do
    data =
      socket.assigns
      |> Map.get(:data)
      |> Data.add_point(map(x, 0, 800, 0, 1), map(y, 0, 800, 1, 0))

    assign(socket, data: data)
  end
```

In the `add_point/2` function we're grabbing the x and y values and assign them to the data struct stored in our socket.

> Also note the call to `map/5` in there. We're calling it twice since we're scaling both the X and Y axis down. The X axis from 0 - 800 to 0-1 and the Y axis from 0 - 800 to 1 - 0. We flipped the Y axis so that it Y = 0 is on the bottom of the SVG.

## Drawing our input

With our RegressionLive module storing inputs, let's adjust the template so it will render all points it has stored. Open up the `regression_live.html.leex` template and make some edits:

```diff
~ <svg phx-click="add_point" width="800" height="800">
+  <%= for {x, y} <- @data.points do %>
+  <circle
+    cx="<%= map(x, 0, 1, 0, 800) %>"
+    cy="<%= map(y, 0, 1, 800, 0) %>"
+    r="5"
+    fill="#24DA5E"
+  />
+  <% end %>
~ </svg>
```

It will now iterate over all the points in the `data` struct and passing them through the `map/5` function to map the coordinates to 0 - 800 again. It looks like:

{{< figure src="/resources/linreg-ii/collecting_points.gif" caption="Adding points" >}}

## Drawing the predicted line

Now that we have a canvas that renders our collected points, let's hook it up to our linear regression algorithm and let it draw its predicted line.

To draw that line, we need to know the Y value for X = 0 to get the starting point, and Y when x = 800 (the width of our canvas), as our end point, to draw a line between those two points. We'll store both those values on the socket too as `start_y` and `end_y`:

```diff
  def mount(_params, _sesion, socket) do
    socket =
      socket
      |> assign(model: Linreg.Model.new())
      |> assign(data: Linreg.Data.new())
+     |> assign(start_y: 0)
+     |> assign(end_y: 0)

    {:ok, socket}
  end
```

In our template we can use these values to draw the line:

```diff
<svg phx-click="add_point" width="800" height="800">
  <%= for {x, y} <- @data.points do %>
  <circle
    cx="<%= map(x, 0, 1, 0, 800) %>"
    cy="<%= map(y, 0, 1, 800, 0) %>"
    r="5"
    fill="#24DA5E"
  />
  <% end %>

+ <line
+   x1="0"
+   y1="<%= map(@start_y, 0, 1, 800, 0) %>"
+   x2="800"
+   y2="<%= map(@end_y, 0, 1, 800, 0) %>"
+   stroke-width="1"
+   stroke="#2477DA"
+ />
</svg>
```

We've added a `line` element which takes two X and Y pairs to indicate the start and end points of the line. As you can see these points are passed through our `map/5` function as well before using them in the template.

## Learning

When adding new points we like our model to run the training adjusting its weights and on its turn adjusting the predicted line. To run the training, add the following two functions to our RegressionLive module:

```elixir
defp learn(%{assigns: %{data: data, model: model}} = socket) do
  if length(data.points) >= 2 do
    model = Model.train(model, data, learning_rate: 0.1, epochs: 500)
    assign(socket, model: model)
  else
    socket
  end
end

defp update_prediction(%{assigns: %{model: model}} = socket) do
  socket
  |> assign(start_y: Model.predict(model, 0))
  |> assign(end_y: Model.predict(model, 1))
end
```

The first one: `learn/1` will take the socket and pattern match the training data and the model from the socket. Then, only if there's two or more points in the training set, it'll call the `Model.train/3` function. In this case we're calling it with a learning rate of 0.1 and we'll train it for 500 epochs, but feel free to play with these numbers and observe the output change.

The other function `update_predicton/1` simply takes the socket to pattern match the model out of there, and assigns the `start_y` and `end_y` values in the socket based on the updated model's prediction for X = 0 and X = 1.

Now to use these functions, let's revisit our `add_point/2` function one last time:

```diff
defp add_point(%{"offsetX" => x, "offsetY" => y}, socket) do
  data =
    socket.assigns
    |> Map.get(:data)
    |> Data.add_point(map(x, 0, 800, 0, 1), map(y, 0, 800, 1, 0))

- assign(socket, data: data)
+ socket
+ |> assign(data: data)
+ |> learn()
+ |> update_prediction()
end
```

## Done

And we're done! We've built a linear regression algorithm in Elixir and made it interactive and visual using LiveView!

{{< figure src="/resources/linreg-ii/finished_product.gif" caption="That's a wrap!" >}}

You can find the [full code on GitHub](https://github.com/tmw/linreg). Feel free to play around with it and make it better! Thanks for reading :)
