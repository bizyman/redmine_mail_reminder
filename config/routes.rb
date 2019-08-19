  resources :mail_reminders do
    collection do
      post 'update_interval_values'
      get 'run_reminder_job/:env', to: 'mail_reminders#run_reminder_job'
    end
  end

  resources :query
