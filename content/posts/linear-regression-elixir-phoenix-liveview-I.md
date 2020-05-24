---
title: "Linear Regression with Elixir, Phoenix and Liveview. Part I"
date: 2020-04-28T22:30:03+02:00
draft: false
keywords: linrear regression, machine learning, elixir, liveview
description: Writing a basic linear regression algorithm in Elixir and make it interactive using Phoenix Live View
icon: 📈
---

Phoenix Liveview has been around for [a bit](https://www.youtube.com/watch?v=8xJzHq8ru0M), but with the release of Phoenix 1.5 it became even easier to get started with it in a new Phoenix app! Simply pass the `--live` flag when generating a new project and off you go! 🚀

In this two part series we're getting our hands dirty with a basic linear regression algorithm that allows the user to click on a plane to add datapoints and the algorithm figure out the best fitting line through these points.

{{< figure src="/resources/linreg-ii/finished_product.gif" caption="The endresult!" >}}

## Upgrading to Phoenix 1.5.x

To kick things off, we first need to get up-to-date with our Phoenix version, if you have not already done this. You can do so by running: `mix archive.install hex phx_new`

If you rather get LiveView to work on Phoenix 1.4.x, just follow [the getting started guide](https://hexdocs.pm/phoenix_live_view/installation.html).

## Setting up the project

Generating a new project that will help us hit the ground running is as simple as: `mix phx.new linreg --live --no-ecto`.

Note the two flags there:

- `--no-ecto` skips setting up all Ecto related things since we won't be using them in this project.

- `--live` ensures everything is wired up to use LiveView!

Lastly; `cd` into the `linreg` folder and kick-off the Phoenix server by running `mix phx.server`. You are now greeted by the getting started page over at `http://localhost:4000`. 🎉

## Basic model

Now that we have a new Elixir, Phoenix and LiveView project ready to go, we can get cracking on the real stuff!

First things first, let's define a simple model to hold our data and make our predictions with. A simple struct to hold our weights will do! Fire up your favorite editor and create a new file under `lib/linreg/`. Let’s call it `model.ex` by lack of a better name and drop in the following code:

```elixir
defmodule Linreg.Model do
  defstruct m: 0.0, b: 0.0

  alias __MODULE__

  def new do
    %Model{}
  end

  def predict(%Model{m: m, b: b}, x) do
    b + m * x
  end
end
```

The module starts off pretty basic. It defines a struct to keep track of two values: M and B and define a function to make predictions based off of the model. For convenience I added a factory function that returns a new empty `%Model{}` struct.

## What is training

Without training, our model would always return 0.0. This is because the weights aren't adjusted yet. There's a variety of ways to let the machine learn the correct values for M and B, but basically it all boils down to:

1. Let the model make a prediction,
2. Calculate how far it is off (often called error, loss or cost),
3. Adjust the weights accordingly and repeat. Repeat until the error is acceptably low.

## Gather training data

In order to correctly train our model, we need training data. Training data in our case means a set of X and Y value pairs. The model can learn from these values by making a prediction based on X and see how far it is off by looking at the actual Y value.

In the `lib/linreg` folder, go ahead and make a new file called `data.ex` and write the following code:

```elixir
defmodule Linreg.Data do
  defstruct points: []
  alias __MODULE__

  def new do
    %Data{}
  end

  def add_point(%Data{points: points} = data, x, y) do
    %Data{data | points: [{x, y}] ++ points}
  end
end
```

In this module we define a struct that holds our training data. A list of X and Y coordinates called _points_. and some utility functions to initialize a new `%Data{}` struct and to add a point to an existing dataset.

## Adjusting the weights

Now that we can record training data, we can implement a training function that adjusts the weights of our model. Open `lib/linreg/model.ex` and write the following function:

```elixir
def train(%Model{m: m, b: b} = model, %Data{points: points}, opts \\ []) do
  learning_rate = Keyword.get(opts, :learning_rate, 0.01)

  m_error =
    points
    |> Enum.map(fn {x, y} -> x * (predict(model, x) - y) end)
    |> Enum.sum()
    |> Kernel./(length(points))

  b_error =
    points
    |> Enum.map(fn {x, y} -> predict(model, x) - y end)
    |> Enum.sum()
    |> Kernel./(length(points))

  %Model{model | m: m - m_error * learning_rate, b: b - b_error * learning_rate}
end
```

The `train/3` function takes the current model, training data and a list of options. Then for each point in the training set, it will make a prediction of the Y value given its X value and calculate how far it is off.

It will do this for both the M and the B values. Only difference is that, for M, we’re constraining the result by multiplying it with its input X value. Once we have the errors for each datapoint, we take the average.

Once we have the average error of the model, we adjust each weight by subtracting the average corresponding error multiplied by the _learning rate_.

> The learning rate is a value, often between 0 and 1, which determines _how quick_ the machine learns. It ensures that the adjustments to the weights are done in very small steps as to not overshoot the optimum value. This process is called gradient descent and is a very common technique within machine learning algorithms.

## Taking it for a spin

That’s pretty much all there is to it! Now let’s take it for a spin and see how it works. Fire up an iEX shell again and let’s make some predictions.

```elixir
# Initialize new trainings data and a new model
iex> d = Linreg.Data.new
%Linreg.Data{points: []}

iex> m = Linreg.Model.new
%Linreg.Model{b: 0.0, m: 0.0}

# Add some known data to the training set
iex> d = Linreg.Data.add_point(d, 2, 4)
%Linreg.Data{points: [{2, 4}]}

iex> d = Linreg.Data.add_point(d, 6, 12)
%Linreg.Data{points: [{6, 12}, {2, 4}]}

# Train the model
iex> m = Model.train(m, d)
%Linreg.Model{b: 0.08, m: 0.4}

# Predict our first value
iex> Model.predict(m, 5)
2.08
```

In the example above we’ve created a model and fed it some pretty straight forward trainings data where `Y = 2 * X`. We trained our model and let it make a prediction for 5. We expect it to predict 10, however it predicts 2 and some change.. We are getting closer, but the error is still pretty high.

What we see here is the learning rate in effect! We take smaller steps so we don’t overshoot our goal, however that also means that simply iterating over the training set once, will not cut it.

> In machine learning; iterating over the trainings set once is referred to as one epoch. In most machine learning algorithms, it requires iterating over your data set many times. Each time shaving some points off of the error, each time perfecting the model’s weights a bit more.

Running the training and prediction functions again yield in values a little closer to what we expect.

## Multiple epochs

In order to make training for multiple epochs a little easier, let’s revisit the `train/3` function one more time and make it iterate over the entire training set multiple times.

```elixir
def train(%Model{} = model, %Data{points: points}, opts \\ []) do
  learning_rate = Keyword.get(opts, :learning_rate, 0.01)
  epochs = Keyword.get(opts, :epochs, 100)

  for _epoch <- 1..epochs, reduce: model do
    %Model{m: m, b: b} = model ->
      m_error =
        points
        |> Enum.map(fn {x, y} -> x * (predict(model, x) - y) end)
        |> Enum.sum()
        |> Kernel./(length(points))

      b_error =
        points
        |> Enum.map(fn {x, y} -> predict(model, x) - y end)
        |> Enum.sum()
        |> Kernel./(length(points))

      %Model{model | m: m - m_error * learning_rate, b: b - b_error * learning_rate}
  end
end
```

We made a few changes to the train function. First off: We’re defining an epoch value which will determine how many times we run through the entire training set. Secondly; we wrapped the whole function body in an for comprehension so that we can iterate through the entire training set multiple times, each time adjusting the weights a little bit more.

> Note that we’re using a [comprehension with the reduce option](https://hexdocs.pm/elixir/Kernel.SpecialForms.html?#for/1-the-reduce-option). This is essentially the same as [`Enum.reduce/3`](https://hexdocs.pm/elixir/Enum.html#reduce/3) but is a little easier on the eyes with larger bodies, but that might just be a matter of taste 😗

## More training

Now that we’ve advanced our training function, let’s try it out and see if our predictions will get a little closer this time! Fire up the IEx again (`iex -S mix`) and run:

```elixir
iex> d = Linreg.Data.add_point(d, 2, 4)
%Linreg.Data{points: [{2, 4}]}

iex> d = Linreg.Data.add_point(d, 8, 16)
%Linreg.Data{points: [{8, 16}, {2, 4}]}

iex> m = Linreg.Model.train(m, d)
%Linreg.Model{b: 0.22374565348607184, m: 1.966843594782793}

iex> Linreg.Model.predict(m, 5)
10.057963627400037
```

Hooray! We trained our model the formula `Y = 2 * X + 0`. More or less. As you can see the values for M and B are still a bit off, but given enough training, these values will approach the correct values more and more.

I’m saying approach here; they will never exactly be 2 and 0. This is mainly due to the learning rate, but floating point arithmetic is also to blame here.

## Try for yourself

The previous example is using a learning rate of 0.01 and trains for 100 epochs, these values are overridable in the options and will yield different results. Simply by calling our training function with the options list:

```elixir
iex> m = Model.train(m, d, learning_rate: 0.1, epochs: 500)
```

I’ll leave it as an exercise to the reader to play a bit with these values and see what happens.

## Closing words

That’s it for this post! We built a machine learning model that can perform linear regressions and trained it using gradient descent in Elixir.

In the [next part](/posts/linear-regression-elixir-phoenix-liveview-ii/) we’ll look at how we can make this an interactive example using Phoenix Liveview where clicking on a SVG plane will generate training data and let the model predict the best fitting line through those points.
