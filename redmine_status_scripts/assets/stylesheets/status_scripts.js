// plugins/redmine_status_scripts/assets/javascripts/status_scripts.js

document.addEventListener('DOMContentLoaded', function() {
  initStatusScripts();
});

function initStatusScripts() {
  // Toggle Log Details
  initLogDetailsToggle();
  
  // Form Enhancements
  initFormEnhancements();
  
  // Filter Toggle
  initFilterToggle();
  
  // Confirmation Dialogs
  initConfirmationDialogs();
}

/**
 * Toggle Details in Log Tables
 */
function initLogDetailsToggle() {
  const toggleButtons = document.querySelectorAll('.toggle-details');
  
  toggleButtons.forEach(function(button) {
    button.addEventListener('click', function(e) {
      e.preventDefault();
      
      const row = this.closest('tr');
      const detailsRow = row.nextElementSibling;
      
      if (detailsRow && detailsRow.classList.contains('log-details')) {
        const isVisible = detailsRow.style.display !== 'none';
        
        if (isVisible) {
          detailsRow.style.display = 'none';
          this.classList.remove('expanded');
          this.title = 'Details anzeigen';
        } else {
          detailsRow.style.display = 'table-row';
          this.classList.add('expanded');
          this.title = 'Details ausblenden';
        }
      }
    });
  });
}

/**
 * Form Enhancements
 */
function initFormEnhancements() {
  // Script Type Change Handler
  const scriptTypeSelect = document.getElementById('script_type_select');
  if (scriptTypeSelect) {
    scriptTypeSelect.addEventListener('change', updateScriptFields);
    updateScriptFields(); // Initial call
  }
  
  // Code Editor Enhancements
  initCodeEditor();
  
  // Real-time Validation
  initFormValidation();
}

function updateScriptFields() {
  const scriptType = document.getElementById('script_type_select').value;
  const webhookField = document.getElementById('webhook_url_field');
  const contentField = document.getElementById('script_content_field');
  const contentTextarea = document.querySelector('#status_script_config_script_content');
  
  // Hide all fields first
  if (webhookField) webhookField.style.display = 'none';
  if (contentField) contentField.style.display = 'none';
  
  if (scriptType === 'webhook') {
    if (webhookField) webhookField.style.display = 'block';
  } else if (scriptType === 'shell' || scriptType === 'ruby') {
    if (contentField) contentField.style.display = 'block';
    
    // Update placeholder based on script type
    if (contentTextarea) {
      updateCodeEditorPlaceholder(contentTextarea, scriptType);
    }
  }
  
  // Update validation
  updateFieldValidation(scriptType);
}

function updateCodeEditorPlaceholder(textarea, scriptType) {
  const placeholders = {
    shell: `#!/bin/bash
echo "Issue $REDMINE_ISSUE_ID changed to $REDMINE_NEW_STATUS_NAME"
echo "Project: $REDMINE_PROJECT_NAME"
echo "Assignee: $REDMINE_ASSIGNEE_NAME"

# Beispiel: Slack-Benachrichtigung
curl -X POST -H 'Content-type: application/json' \\
  --data "{\\"text\\":\\"Issue #$REDMINE_ISSUE_ID wurde auf '$REDMINE_NEW_STATUS_NAME' gesetzt\\"}" \\
  https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK`,
    
    ruby: `# Zugriff auf Parameter über @variablen
puts "Issue #{@issue_id}: #{@issue_subject}"
puts "Status: #{@old_status_name} → #{@new_status_name}"

# Beispiel: E-Mail versenden
if @new_status_name == 'Resolved'
  # UserMailer.issue_resolved(@issue_id).deliver_now
end

# Beispiel: HTTP-Request
require 'net/http'
uri = URI('https://your-api.com/webhook')
Net::HTTP.post_form(uri, {
  'issue_id' => @issue_id,
  'status' => @new_status_name
})`
  };
  
  textarea.placeholder = placeholders[scriptType] || '';
}

function updateFieldValidation(scriptType) {
  const webhookUrl = document.querySelector('#status_script_config_webhook_url');
  const scriptContent = document.querySelector('#status_script_config_script_content');
  
  if (webhookUrl) {
    webhookUrl.required = (scriptType === 'webhook');
  }
  
  if (scriptContent) {
    scriptContent.required = (scriptType === 'shell' || scriptType === 'ruby');
  }
}

/**
 * Code Editor Enhancements
 */
function initCodeEditor() {
  const codeEditors = document.querySelectorAll('.code-editor');
  
  codeEditors.forEach(function(editor) {
    // Tab support
    editor.addEventListener('keydown', function(e) {
      if (e.key === 'Tab') {
        e.preventDefault();
        const start = this.selectionStart;
        const end = this.selectionEnd;
        
        // Insert tab character
        this.value = this.value.substring(0, start) + 
                    '  ' + // 2 spaces instead of tab
                    this.value.substring(end);
        
        // Move cursor
        this.selectionStart = this.selectionEnd = start + 2;
      }
    });
    
    // Auto-resize
    editor.addEventListener('input', function() {
      autoResizeTextarea(this);
    });
    
    // Initial resize
    autoResizeTextarea(editor);
  });
}

function autoResizeTextarea(textarea) {
  textarea.style.height = 'auto';
  textarea.style.height = Math.min(textarea.scrollHeight, 400) + 'px';
}

/**
 * Form Validation
 */
function initFormValidation() {
  const form = document.querySelector('form.tabular');
  if (!form) return;
  
  // Real-time validation
  const requiredFields = form.querySelectorAll('[required]');
  requiredFields.forEach(function(field) {
    field.addEventListener('blur', function() {
      validateField(this);
    });
    
    field.addEventListener('input', function() {
      clearFieldError(this);
    });
  });
  
  // Form submit validation
  form.addEventListener('submit', function(e) {
    if (!validateForm(this)) {
      e.preventDefault();
    }
  });
}

function validateField(field) {
  const isValid = field.checkValidity();
  const fieldContainer = field.closest('p');
  
  if (!isValid && fieldContainer) {
    fieldContainer.classList.add('field-error');
    showFieldError(field, field.validationMessage);
  } else if (fieldContainer) {
    fieldContainer.classList.remove('field-error');
    clearFieldError(field);
  }
  
  return isValid;
}

function validateForm(form) {
  let isValid = true;
  const requiredFields = form.querySelectorAll('[required]');
  
  requiredFields.forEach(function(field) {
    if (!validateField(field)) {
      isValid = false;
    }
  });
  
  // Custom validation for script type
  const scriptType = document.getElementById('script_type_select');
  if (scriptType && scriptType.value) {
    const webhookUrl = document.querySelector('#status_script_config_webhook_url');
    const scriptContent = document.querySelector('#status_script_config_script_content');
    
    if (scriptType.value === 'webhook' && webhookUrl && !webhookUrl.value.trim()) {
      validateField(webhookUrl);
      isValid = false;
    }
    
    if ((scriptType.value === 'shell' || scriptType.value === 'ruby') && 
        scriptContent && !scriptContent.value.trim()) {
      validateField(scriptContent);
      isValid = false;
    }
  }
  
  return isValid;
}

function showFieldError(field, message) {
  clearFieldError(field);
  
  const errorElement = document.createElement('span');
  errorElement.className = 'field-error-message';
  errorElement.textContent = message;
  
  field.parentNode.appendChild(errorElement);
}

function clearFieldError(field) {
  const existingError = field.parentNode.querySelector('.field-error-message');
  if (existingError) {
    existingError.remove();
  }
}

/**
 * Filter Toggle
 */
function initFilterToggle() {
  const filterLegends = document.querySelectorAll('fieldset.collapsible legend');
  
  filterLegends.forEach(function(legend) {
    legend.addEventListener('click', function() {
      toggleFieldset(this);
    });
  });
}

function toggleFieldset(legend) {
  const fieldset = legend.parentNode;
  const content = fieldset.querySelector('div');
  
  if (content) {
    const isCollapsed = content.style.display === 'none';
    content.style.display = isCollapsed ? 'block' : 'none';
    fieldset.classList.toggle('collapsed', !isCollapsed);
  }
}

/**
 * Confirmation Dialogs
 */
function initConfirmationDialogs() {
  const confirmLinks = document.querySelectorAll('a[data-confirm], input[data-confirm]');
  
  confirmLinks.forEach(function(element) {
    element.addEventListener('click', function(e) {
      const message = this.getAttribute('data-confirm') || 
                     this.getAttribute('confirm') ||
                     'Sind Sie sicher?';
      
      if (!confirm(message)) {
        e.preventDefault();
        return false;
      }
    });
  });
}

/**
 * Utility Functions
 */

// AJAX Helper
function sendAjaxRequest(url, options = {}) {
  const defaults = {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest'
    }
  };
  
  const config = Object.assign(defaults, options);
  
  return fetch(url, config)
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    })
    .catch(error => {
      console.error('AJAX request failed:', error);
      throw error;
    });
}

// Flash Message Helper
function showFlashMessage(message, type = 'notice') {
  const flashContainer = document.getElementById('flash_' + type) || 
                        createFlashContainer(type);
  
  flashContainer.textContent = message;
  flashContainer.style.display = 'block';
  
  // Auto-hide after 5 seconds
  setTimeout(function() {
    flashContainer.style.display = 'none';
  }, 5000);
}

function createFlashContainer(type) {
  const container = document.createElement('div');
  container.id = 'flash_' + type;
  container.className = 'flash ' + type;
  container.style.display = 'none';
  
  const content = document.querySelector('#content') || document.body;
  content.insertBefore(container, content.firstChild);
  
  return container;
}

// Table Enhancement
function enhanceTable(tableSelector) {
  const table = document.querySelector(tableSelector);
  if (!table) return;
  
  // Add sorting capability
  const headers = table.querySelectorAll('th');
  headers.forEach(function(header, index) {
    if (header.textContent.trim() && !header.classList.contains('buttons')) {
      header.style.cursor = 'pointer';
      header.addEventListener('click', function() {
        sortTable(table, index);
      });
    }
  });
}

function sortTable(table, columnIndex) {
  const rows = Array.from(table.querySelectorAll('tbody tr:not(.log-details)'));
  const isNumeric = checkIfNumericColumn(rows, columnIndex);
  const isAscending = !table.getAttribute('data-sort-asc');
  
  rows.sort(function(a, b) {
    const aText = getCellText(a, columnIndex);
    const bText = getCellText(b, columnIndex);
    
    let result;
    if (isNumeric) {
      result = parseFloat(aText) - parseFloat(bText);
    } else {
      result = aText.localeCompare(bText);
    }
    
    return isAscending ? result : -result;
  });
  
  // Re-insert sorted rows
  const tbody = table.querySelector('tbody');
  rows.forEach(function(row) {
    tbody.appendChild(row);
    
    // Also move detail rows if they exist
    const detailRow = row.nextElementSibling;
    if (detailRow && detailRow.classList.contains('log-details')) {
      tbody.appendChild(detailRow);
    }
  });
  
  table.setAttribute('data-sort-asc', isAscending);
  
  // Update header indicators
  const headers = table.querySelectorAll('th');
  headers.forEach(function(header) {
    header.classList.remove('sort-asc', 'sort-desc');
  });
  headers[columnIndex].classList.add(isAscending ? 'sort-asc' : 'sort-desc');
}

function getCellText(row, columnIndex) {
  const cell = row.children[columnIndex];
  return cell ? cell.textContent.trim() : '';
}

function checkIfNumericColumn(rows, columnIndex) {
  const sampleSize = Math.min(3, rows.length);
  for (let i = 0; i < sampleSize; i++) {
    const text = getCellText(rows[i], columnIndex);
    if (text && !isNaN(parseFloat(text))) {
      return true;
    }
  }
  return false;
}

// Export functions for global access
window.StatusScripts = {
  updateScriptFields: updateScriptFields,
  toggleFieldset: toggleFieldset,
  showFlashMessage: showFlashMessage,
  enhanceTable: enhanceTable
};