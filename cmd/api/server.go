package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func (app *application) serve() error {
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", app.config.port),
		Handler:      app.routes(),
		IdleTimeout:  time.Minute,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}
	// creating a error channel to receive any errors returned
	// by the shutdown function
	shutdownError := make(chan error)

	go func() {
		quit := make(chan os.Signal, 1)

		// listen for incoming SIGINT and SIGTERM signals
		// and relay them to the quit channel
		signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

		// read the signal from quit channel.
		// this will block until a signal is received
		s := <-quit

		app.logger.PrintInfo("shutting down server", map[string]string{
			"signal": s.String(),
		})

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		// call Shutdown on our server, passing context
		// relay this return value to the shutdownError channel
		shutdownError <- srv.Shutdown(ctx)
	}()

	app.logger.PrintInfo("starting server", map[string]string{
		"addr": srv.Addr,
		"env":  app.config.env,
	})

	// shutting down will return server closed error.
	// make sure we are seeing the correct error
	err := srv.ListenAndServe()
	if !errors.Is(err, http.ErrServerClosed) {
		return err
	}

	// we wait to receive the return value from Shutdown() on the channel
	// if server is not shut down, this will block execution here.
	err = <-shutdownError
	if err != nil {
		return err
	}

	app.logger.PrintInfo("stopped server", map[string]string{
		"addr": srv.Addr,
	})

	return nil
}
