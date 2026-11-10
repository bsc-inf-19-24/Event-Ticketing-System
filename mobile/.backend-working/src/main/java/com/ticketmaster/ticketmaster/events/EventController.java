
package com.ticketmaster.ticketmaster.events;

import com.ticketmaster.ticketmaster.events.dto.EventResponse;
import com.ticketmaster.ticketmaster.events.entity.Event;
import com.ticketmaster.ticketmaster.events.entity.EventService;
import io.swagger.v3.oas.annotations.Operation;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@RestController
@RequestMapping("/api/events")
public class EventController {

    private final EventService eventService;

    public EventController(EventService eventService) {
        this.eventService = eventService;
    }

    // Create an event
    @PostMapping
    @Operation(summary = "Create a draft event for the authenticated organizer")
    @ResponseStatus(HttpStatus.CREATED)
    public Event createEvent(
            @RequestBody Event event,
            Authentication authentication) {

        return eventService.createEvent(
                event, getOrganizerUsername(authentication));
    }

    // Get all events
    @GetMapping
    @Operation(summary = "List published and cancelled events with optional filters")
    public List<EventResponse> getAllEvents(
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String search) {
        return eventService.getAllEvents(category, search);
    }

    // Get one event
    @GetMapping("/{id}")
    @Operation(summary = "Get event details; draft events are visible only to their owner")
    public EventResponse getEventById(@PathVariable Long id, Authentication authentication) {
        String requesterEmail = authentication == null ? null : authentication.getName();
        return eventService.getEventResponseById(id, requesterEmail);
    }

    // Edit an event
    @PutMapping("/{id}")
    @Operation(summary = "Update an owned event")
    public Event editEvent(
            @PathVariable Long id,
            @RequestBody Event event,
            Authentication authentication) {

        return eventService.editEvent(
                id, event, authentication == null ? null : authentication.getName());
    }

    // Publish an event
    @PatchMapping("/{id}/publish")
    @Operation(summary = "Publish an owned event")
    public Event publishEvent(
            @PathVariable Long id,
            Authentication authentication) {

        return eventService.publishEvent(
                id, authentication == null ? null : authentication.getName());
    }

    // Cancel an event
    @PatchMapping("/{id}/cancel")
    @Operation(summary = "Cancel an owned event")
    public Event cancelEvent(
            @PathVariable Long id,
            Authentication authentication) {

        return eventService.cancelEvent(
                id, authentication == null ? null : authentication.getName());
    }

    // Get username from the logged-in user
    private String getOrganizerUsername(Authentication authentication) {
        if (authentication == null
                || !authentication.isAuthenticated()
                || "anonymousUser".equals(authentication.getPrincipal())) {

            throw new ResponseStatusException(
                    HttpStatus.UNAUTHORIZED,
                    "Please log in first");
        }

        return authentication.getName();
    }
}
