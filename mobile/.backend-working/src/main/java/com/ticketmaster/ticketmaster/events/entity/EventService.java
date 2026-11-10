package com.ticketmaster.ticketmaster.events.entity;

import com.ticketmaster.ticketmaster.common.exception.NotFoundException;
import com.ticketmaster.ticketmaster.events.EventCancelledEvent;
import com.ticketmaster.ticketmaster.events.dto.EventResponse;
import com.ticketmaster.ticketmaster.events.dto.EventResponse.TicketTypeResponse;
import com.ticketmaster.ticketmaster.user.entity.User;
import com.ticketmaster.ticketmaster.user.repository.UserRepository;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class EventService {

    private final ApplicationEventPublisher eventPublisher;
    private final EventRepository eventRepository;
    private final TicketTypeRepository ticketTypeRepository;
    private final UserRepository userRepository;

    public EventService(EventRepository eventRepository, ApplicationEventPublisher eventPublisher,
            TicketTypeRepository ticketTypeRepository, UserRepository userRepository) {
        this.eventRepository = eventRepository;
        this.eventPublisher = eventPublisher;
        this.ticketTypeRepository = ticketTypeRepository;
        this.userRepository = userRepository;
    }

    public Event createEvent(Event event, String organizerUsername) {
        if (organizerUsername == null || organizerUsername.isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Organizer must be authenticated");
        }
        User organizer = userRepository.findByEmail(organizerUsername)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.UNAUTHORIZED, "Authenticated user not found."));
        validateEventTimes(event);
        event.setOrganizerUsername(organizerUsername);
        event.setOrganizerId(organizer.getId());
        event.setStatus(EventStatus.DRAFT);
        return eventRepository.save(event);
    }

    @Transactional(readOnly = true)
    public List<EventResponse> getAllEvents(String category, String search) {
        String normalizedCategory = normalize(category);
        String normalizedSearch = normalize(search);
        List<Event> events = eventRepository.findByStatusInOrderByStartTimeAsc(
                        List.of(EventStatus.PUBLISHED, EventStatus.CANCELLED))
                .stream()
                .filter(event -> normalizedCategory == null
                        || Objects.equals(normalize(event.getCategory() == null
                                ? "Other" : event.getCategory()), normalizedCategory))
                .filter(event -> normalizedSearch == null || matchesSearch(event, normalizedSearch))
                .toList();
        Map<Long, List<TicketType>> typesByEventId = ticketTypesFor(events);
        return events.stream()
                .map(event -> toResponse(event, typesByEventId.getOrDefault(event.getId(), List.of())))
                .toList();
    }

    @Transactional(readOnly = true)
    public EventResponse getEventResponseById(Long id, String requesterEmail) {
        Event event = getEvent(id);
        if (event.getStatus() == EventStatus.DRAFT && !isOwner(event, requesterEmail)) {
            throw new NotFoundException("Event not found.");
        }
        List<TicketType> ticketTypes = ticketTypeRepository.findByEventIdOrderByPriceAsc(id);
        return toResponse(event, ticketTypes);
    }

    public Event editEvent(Long id, Event updatedEvent, String organizerUsername) {
        Event existingEvent = getEvent(id);
        checkOrganizer(existingEvent, organizerUsername);
        if (existingEvent.getStatus() != EventStatus.DRAFT) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Only draft events can be edited");
        }
        if (updatedEvent.getStartTime() == null && updatedEvent.getDateTime() == null) {
            updatedEvent.setStartTime(existingEvent.getStartTime());
        }
        if (updatedEvent.getGenre() == null) {
            updatedEvent.setGenre(existingEvent.getGenre());
        }
        if (updatedEvent.getCategory() == null || updatedEvent.getCategory().isBlank()) {
            updatedEvent.setCategory(existingEvent.getCategory());
        }
        if (updatedEvent.getVenue() == null) {
            updatedEvent.setVenue(existingEvent.getVenue());
        }
        if (updatedEvent.getLocation() == null) {
            updatedEvent.setLocation(existingEvent.getLocation());
        }
        if (updatedEvent.getEndTime() == null) {
            updatedEvent.setEndTime(existingEvent.getEndTime());
        }
        validateEventTimes(updatedEvent);
        existingEvent.setTitle(updatedEvent.getTitle());
        existingEvent.setCategory(updatedEvent.getCategory());
        existingEvent.setGenre(updatedEvent.getGenre());
        existingEvent.setVenue(updatedEvent.getVenue());
        existingEvent.setLocation(updatedEvent.getLocation());
        existingEvent.setDateTime(updatedEvent.getDateTime());
        existingEvent.setStartTime(updatedEvent.getStartTime());
        existingEvent.setEndTime(updatedEvent.getEndTime());
        return eventRepository.save(existingEvent);
    }

    public Event publishEvent(Long id, String organizerUsername) {
        Event event = getEvent(id);
        checkOrganizer(event, organizerUsername);
        if (event.getStatus() == EventStatus.CANCELLED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Cancelled events cannot be published.");
        }
        if (event.getStatus() != EventStatus.DRAFT) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Only draft events can be published");
        }
        if (ticketTypeRepository.findByEventId(event.getId()).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Add at least one ticket type before publishing.");
        }
        validateEventTimes(event);
        event.setStatus(EventStatus.PUBLISHED);
        return eventRepository.save(event);
    }

    public Event cancelEvent(Long id, String organizerUsername) {
        Event event = getEvent(id);
        checkOrganizer(event, organizerUsername);
        if (event.getStatus() == EventStatus.CANCELLED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Event is already cancelled");
        }
        boolean wasPublished = (event.getStatus() == EventStatus.PUBLISHED);
        event.setStatus(EventStatus.CANCELLED);
        Event savedEvent = eventRepository.save(event);
        if (wasPublished) {
            eventPublisher.publishEvent(new EventCancelledEvent(this, savedEvent.getId(), savedEvent.getTitle()));
        }
        return savedEvent;
    }

    private Event getEvent(Long id) {
        return eventRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Event not found."));
    }

    private boolean isOwner(Event event, String requesterEmail) {
        if (requesterEmail == null || requesterEmail.isBlank()) {
            return false;
        }
        if (requesterEmail.equals(event.getOrganizerUsername())) {
            return true;
        }
        return event.getOrganizerId() == null
                && userRepository.findByEmail(requesterEmail)
                        .map(User::getEmail)
                        .filter(event.getOrganizerUsername()::equals)
                        .isPresent()
                || (event.getOrganizerId() != null
                && userRepository.findByEmail(requesterEmail)
                        .map(User::getId)
                        .filter(event.getOrganizerId()::equals)
                        .isPresent());
    }

    private Map<Long, List<TicketType>> ticketTypesFor(List<Event> events) {
        if (events.isEmpty()) {
            return Map.of();
        }
        List<Long> eventIds = events.stream().map(Event::getId).toList();
        return ticketTypeRepository.findByEventIdInOrderByPriceAsc(eventIds).stream()
                .collect(Collectors.groupingBy(
                        type -> type.getEvent().getId(),
                        java.util.LinkedHashMap::new,
                        Collectors.toList()));
    }

    private EventResponse toResponse(Event event, List<TicketType> ticketTypes) {
        LocalDateTime startTime = event.getStartTime() != null
                ? event.getStartTime() : event.getDateTime();
        long capacity = ticketTypes.stream()
                .mapToLong(type -> type.getTotalQuantity() == null ? 0 : type.getTotalQuantity())
                .sum();
        long remaining = ticketTypes.stream()
                .mapToLong(type -> type.getRemaining() == null ? 0 : type.getRemaining())
                .sum();
        var minPrice = ticketTypes.stream()
                .map(TicketType::getPrice)
                .filter(Objects::nonNull)
                .min(java.math.BigDecimal::compareTo)
                .orElse(java.math.BigDecimal.ZERO);

        return new EventResponse(
                event.getId(),
                event.getTitle(),
                event.getCategory() == null ? "Other" : event.getCategory(),
                event.getGenre(),
                event.getVenue(),
                event.getLocation(),
                startTime,
                event.getEndTime(),
                event.getStatus(),
                availability(event, remaining, !ticketTypes.isEmpty()),
                event.getCoverImagePath(),
                minPrice,
                capacity,
                remaining,
                ticketTypes.stream()
                        .map(type -> new TicketTypeResponse(
                                type.getId(), type.getName(), type.getPrice(),
                                type.getTotalQuantity(), type.getRemaining()))
                        .toList());
    }

    private String availability(Event event, long remainingTickets, boolean hasTicketTypes) {
        if (event.getStatus() == EventStatus.CANCELLED) {
            return "CANCELLED";
        }
        LocalDateTime now = LocalDateTime.now();
        if ((event.getEndTime() != null && !event.getEndTime().isAfter(now))
                || (event.getStartTime() != null && !event.getStartTime().isAfter(now))) {
            return "ENDED";
        }
        return hasTicketTypes && remainingTickets == 0 ? "SOLD_OUT" : "AVAILABLE";
    }

    private boolean matchesSearch(Event event, String search) {
        return contains(event.getTitle(), search)
                || contains(event.getVenue(), search)
                || contains(event.getLocation(), search);
    }

    private boolean contains(String value, String search) {
        return value != null && value.toLowerCase(Locale.ROOT).contains(search);
    }

    private String normalize(String value) {
        return value == null || value.isBlank()
                ? null
                : value.trim().toLowerCase(Locale.ROOT);
    }

    private void validateEventTimes(Event event) {
        if (event.getStartTime() == null && event.getDateTime() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Event start time and end time are required");
        }
        if (event.getStartTime() == null && event.getDateTime() != null) {
            event.setStartTime(event.getDateTime());
        }
        if (event.getDateTime() == null && event.getStartTime() != null) {
            event.setDateTime(event.getStartTime());
        }
        if (event.getCategory() == null || event.getCategory().isBlank()) {
            event.setCategory("Other");
        }
        if (event.getStartTime() != null) {
            event.setStartTime(event.getStartTime().withNano(0));
        }
        if (event.getEndTime() != null) {
            event.setEndTime(event.getEndTime().withNano(0));
        }
        if (event.getStartTime() == null || event.getEndTime() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Event start time and end time are required");
        }
        if (!event.getEndTime().isAfter(event.getStartTime())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "End time must be after start time.");
        }
    }

    private void checkOrganizer(Event event, String organizerUsername) {
        if (organizerUsername != null && !organizerUsername.isBlank()
                && !isOwner(event, organizerUsername)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "Only the event organizer can perform this action");
        }
    }
}