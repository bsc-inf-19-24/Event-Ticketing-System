package com.ticketmaster.ticketmaster.events;

import com.ticketmaster.ticketmaster.common.exception.NotFoundException;
import com.ticketmaster.ticketmaster.events.entity.TicketType;
import com.ticketmaster.ticketmaster.events.entity.TicketTypeRepository;
import com.ticketmaster.ticketmaster.events.entity.TicketTypeService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;

@RestController
@RequestMapping("/api")
public class TicketTypeController {

    private final TicketTypeService service;
    private final TicketTypeRepository ticketTypeRepository;

    public TicketTypeController(TicketTypeService service, TicketTypeRepository ticketTypeRepository) {
        this.service = service;
        this.ticketTypeRepository = ticketTypeRepository;
    }

    public static class CreateTicketTypeRequest {
        public String name;
        public BigDecimal price;
        public Integer totalQuantity;
    }

    @PostMapping("/events/{eventId}/ticket-types")
    @ResponseStatus(HttpStatus.CREATED)
    public TicketType create(@PathVariable Long eventId,
            @RequestBody CreateTicketTypeRequest req,
            Authentication auth) {
        return service.create(eventId, req.name, req.price, req.totalQuantity,
                getUsername(auth));
    }

    @PutMapping("/ticket-types/{id}")
    public TicketType update(@PathVariable Long id,
            @RequestBody CreateTicketTypeRequest req,
            Authentication auth) {
        return service.update(id, req.name, req.price, req.totalQuantity, getUsername(auth));
    }

    @DeleteMapping("/ticket-types/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id, Authentication auth) {
        service.delete(id, getUsername(auth));
    }

    // new
    @GetMapping("/events/{eventId}/ticket-types")
    public List<TicketType> list(
            @PathVariable Long eventId,
            @RequestParam(required = false) String name) {

        List<TicketType> all = ticketTypeRepository.findByEventId(eventId);

        if (name != null && !name.isBlank()) {
            return all.stream()
                    .filter(t -> t.getName().equalsIgnoreCase(name))
                    .toList();
        }
        return all;
    }

@GetMapping("/ticket-types/{id}")
public ResponseEntity<TicketType> getOne(@PathVariable Long id) {
    return ticketTypeRepository.findById(id)
            .map(ResponseEntity::ok)
            .orElseThrow(() -> new NotFoundException("Ticket type not found."));
}





    private String getUsername(Authentication auth) {
        if (auth == null || !auth.isAuthenticated()
                || "anonymousUser".equals(auth.getPrincipal())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please log in first");
        }
        return auth.getName();
    }
}
