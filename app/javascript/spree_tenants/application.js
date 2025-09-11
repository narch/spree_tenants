import '@hotwired/turbo-rails'
import { Application } from '@hotwired/stimulus'

let application

if (typeof window.Stimulus === "undefined") {
  application = Application.start()
  application.debug = false
  window.Stimulus = application
} else {
  application = window.Stimulus
}

import SpreeTenantsController from 'spree_tenants/controllers/spree_tenants_controller' 

application.register('spree_tenants', SpreeTenantsController)